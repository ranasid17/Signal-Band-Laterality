% Script overview:
%   1) Find wavelet span from fwhm, fwhm from span using self-defined functions
%   2) Enter for loop #1 (each loop == 1 pt) 
%       a) Extract pt data into matrix, stratify by ipsi or contralesional recording, apply FFT(*)
%       b) Extract Gabor wavelet using self-defined function, use this to calculate power envelope
%   3) Calculate median laterality for early and late Rest and Task data for all Pts 
%   5) Calculate change in median centroid location "                               " 

% IMPORTANT: (CF, FWHM) are pt-dependent for feature frequencies. So instead of defining one for 
%   entire run, script will iterate thru all 10 when processing each pt.

% Define center frq and wavelet width
cf = [15,16,19,11,11,9,15,11,11,17];
fwhm = 1;

% % Find wavelet span (in time domain)
for i = 1:numel(cf)
    [span(i)] = fwhm2span(cf(i), fwhm); %fwhm2span.m
   % [fwhm] = span2fwhm(cf, span); %span2fwhm.m
end
% Preallocate outside loop to previde overriding w 0s
centDist_alpha_temp_ipsi = zeros(size(200, 20)); 
centDist_ft_ipsi = zeros(size(1, 10)); 

figure()
for i = 1:10
    % Step 1: Data Prep
    % CreateArrayforPCA -> PCA -> CalcCentroid for 10 patients (unpooled data)
    Cell1a = MotorRest{i}; % 30x2000x2x260
    Cell1b = MotorTask{i}; % 30x2000x2x260
    % exceptions for runs to count in early vs late analyses
    cur_subj = ptID(i);
    runsToCount = getRuns2Count(cur_subj,Cell1a);
    %%constrain cell1 to FIRST 5 sessions, ipsi + contra
    ipsiA = Cell1a(:, :, ipsi(i), runsToCount(1:5)); %First 5 REST sessions w no 0s, ipsi
    ipsiB = Cell1b(:, :, ipsi(i), runsToCount(1:5)); %"     " TASK "                    "
    %%constrain cell to LAST 5 sessions, ipsi + contra
    ipsiC = Cell1a(:, :, ipsi(i), runsToCount(6:10)); %Last 5 REST sessions w no 0s, ipsi
    ipsiD = Cell1b(:, :, ipsi(i), runsToCount(6:10)); %"    " TASK "                          "
    
    %%remove singleton dim, change data order, FFT for IPSILATERAL HEMISPHERE
    % DO NOT UNCOMMENT FFT SECTION! CANNOT APPLY FFT AND GABOR FUNCTION TOGETHER, MUST BE ONE OR OTHER!
    ipsiA = squeeze(ipsiA); ipsiA = permute(ipsiA,[2 1 3]); %fftIpsiA = fft(ipsiA);
    ipsiB = squeeze(ipsiB); ipsiB = permute(ipsiB, [2 1 3]); %fftIpsiB = fft(ipsiB);
    ipsiC = squeeze(ipsiC); ipsiC = permute(ipsiC, [2 1 3]); %fftIpsiC = fft(ipsiC);
    ipsiD = squeeze(ipsiD); ipsiD = permute(ipsiD, [2 1 3]); %fftIpsiD = fft(ipsiD);
    
    %%allocate memory
    dataFirstIpsi = zeros(2000, 300);
    dataLastIpsi = zeros(2000, 300);
   
    %%fill array w FFT data
    a = 1;
    while (a<=300)
        for j = 1:5
            %Fill REST sessions (FIRST + LAST), ipsi
            dataFirstIpsi(:, a:a+29) = ipsiA(:, :, j);
            dataLastIpsi(:, a:a+29) = ipsiC(:, :, end-5+j);
            a = a + 30;
        end
        for j = 1:5
            % Fill MOVE 5 sessions (FIRST + LASTT), ipsI
            dataFirstIpsi(:, a:a+29, :) = ipsiB(:, :, j);
            dataLastIpsi(:, a:a+29) = ipsiD(:, :, end-5+j);
            a = a + 30;
        end
    end
    
    % Gabor wavelet function, ipsi (output is complex signal)
    [gabor_responseFirst_ipsi] = gabor_response_span(dataFirstIpsi, cf(i), span(i), Fs);
    [gabor_responseLast_ipsi] = gabor_response_span(dataLastIpsi, cf(i), span(i), Fs);
    %Power envolope, ipsi
    power_envFirst_ipsi = squeeze(abs(gabor_responseFirst_ipsi).^2);
    power_envLast_ipsi = squeeze(abs(gabor_responseLast_ipsi).^2);
    
    % PCA
    % ipsi data
    [coeffF_ipsi, scoreF_ipsi, latentF_ipsi, tsquaredF_ipsi, explainedF_ipsi] = pca(power_envFirst_ipsi);
    [coeffL_ipsi, scoreL_ipsi, latentL_ipsi, tsquaredL_ipsi, explainedL_ipsi] = pca(power_envLast_ipsi);
    
    % Find vars needed to explain 90% variance in each PCA function
    % FIRST 5 trials, ipsi
    EF_ipsi = zeros(size(explainedF_ipsi));
    for j = 1:numel(explainedF_ipsi)
        EF_ipsi(j) = sum(explainedF_ipsi(1:j));
        if (EF_ipsi(j) > 90)
            break
        end
    end
    EF_ipsi(EF_ipsi == 0) = []; %delete extra 0s
    
    % LAST 5 trials, ipsi
    EL_ipsi = zeros(size(explainedL_ipsi));
    for j = 1:numel(explainedL_ipsi)
        EL_ipsi(j) = sum(explainedL_ipsi(1:j));
        if (EL_ipsi(j) > 90)
            break
        end
    end
    EL_ipsi(EL_ipsi == 0) = []; %delete extra 0s
  
    % Plotting centroids, ipsi
    % Center graph axes
    ax = gca;
    ax.XAxisLocation = 'origin'; %move X AXIS location to origin
    ax.YAxisLocation = 'origin'; %move Y AXIS location to origin
    hold on
    
    % ipsi centroid calc
    
    %%Separate PCA data into REST and MOVE (FIRST 5 sessions, ipsi)
    restDataPCAFirst_ipsi = scoreF_ipsi(1:150, :);
    moveDataPCAFirst_ipsi = scoreF_ipsi(151:300, :);
    %%Calc avg of each REST and MOVE COLUMN
    meanRestF_ipsi = mean(restDataPCAFirst_ipsi);
    meanMoveF_ipsi = mean(moveDataPCAFirst_ipsi);
    %%Constrain REST and MOVE to size of EF and EL
    meanRestF_ipsi = meanRestF_ipsi(1:numel(EF_ipsi));
    meanMoveF_ipsi = meanMoveF_ipsi(1:numel(EF_ipsi));
    
    % REPEAT for LAST 5 sessions, ipsi
    
    % Separate PCA data into REST and MOVE (LAST 5)
    restDataPCALast_ipsi = scoreL_ipsi(1:150, :);
    moveDataPCALast_ipsi = scoreL_ipsi(151:300, :);
    %%Calc avg of each REST and MOVE COLUMN
    meanRestL_ipsi = mean(restDataPCALast_ipsi);
    meanMoveL_ipsi = mean(moveDataPCALast_ipsi);
    %%Constrain REST and MOVE to size of EF and EL
    meanRestL_ipsi = meanRestL_ipsi(1:numel(EL_ipsi));
    meanMoveL_ipsi = meanMoveL_ipsi(1:numel(EL_ipsi));
    
    % Calc distance between centroids
    distanceF_ipsi = norm(meanRestF_ipsi - meanMoveF_ipsi);
    distanceL_ipsi = norm(meanRestL_ipsi - meanMoveL_ipsi);
    % Store calc'd distance in centDist
    centDist_alpha_temp_ipsi(1, i) = distanceF_ipsi; %FIRST 5 sessions = Row 1
    centDist_alpha_temp_ipsi(2, i) = distanceL_ipsi; %LAST 5 sessions = Row 2
    %%Calc change from FIRST to LAST 5 sessions
    centDist_ft_ipsi(i) = centDist_temp_ipsi(2, i) - centDist_temp_ipsi(1, i);
    
    % Plot change in ARAT against change in centroid
    scatter(centDist_ft_ipsi(i), ARATchange(i))
    title('Avg change in ipsilat ft frq band position v. ARAT change')
    
end
hold off

%% Step 2: contralesional electrode
% REPEAT STEP 1 FOR LOOP FOR CONTRA DATA
% Preallocate outside loop to previde overriding w 0s
centDist_temp_contra = zeros(size(200,20)); 
centDist_ft_contra = zeros(size(1, 10)); 

figure()
for i = 1:10
    % Step 1: Data Prep
    % CreateArrayforPCA -> PCA -> CalcCentroid for 10 patients (unpooled data)
    Cell1a = MotorRest{i}; % 30x2000x2x260
    Cell1b = MotorTask{i}; % 30x2000x2x260
    % exceptions for runs to count in early vs late analyses
    cur_subj = ptID(i);
    runsToCount = getRuns2Count(cur_subj,Cell1a);
    % constrain cell1 to FIRST 5 sessions, contra
     contraA = Cell1a(:, :, contra(i), runsToCount(1:5)); %First 5 REST sessions w no 0s, contra
     contraB = Cell1b(:, :, contra(i), runsToCount(1:5)); %"     " TASK "                "
    % constrain cell to LAST 5 sessions, contra
     contraC = Cell1a(:, :, contra(i), runsToCount(6:10)); %Last 5 REST sessions w no 0s, contra
     contraD = Cell1a(:, :, contra(i), runsToCount(6:10)); %"    " TASK "                      "
    
    % remove singleton dim, change data order, FFT for CONTRALATERAL HEMISPHERE
    % DO NOT UNCOMMENT FFT SECTION! CANNOT APPLY FFT AND GABOR FUNCTION TOGETHER, MUST BE ONE OR OTHER!
    contraA = squeeze(contraA); contraA = permute(contraA,[2 1 3]); %fftContraA = fft(contraA);
    contraB = squeeze(contraB); contraB = permute(contraB,[2 1 3]); %fftContraB = fft(contraB);
    contraC = squeeze(contraC); contraC = permute(contraC,[2 1 3]); %fftContraC = fft(contraC);
    contraD = squeeze(contraD); contraD = permute(contraD, [2 1 3]); %fftContraD = fft(contraD);
    %%allocate memory
    dataFirstContra = zeros(2000,300);
    dataLastContra = zeros(2000, 300);
    % fill array w FFT data
    a = 1;
    while (a<=300)
        for j = 1:5
            %Fill FIRST 5 sessions (REST + MOVE), contra
            dataFirstContra(:, a:a+29) = contraA(:, :, j);
            dataLastContra(:, a:a+29) = contraC(:, :, end-5+j);
            a = a + 30;
        end
        for j = 1:5
            %Fill LAST 5 sessions (REST + MOVE), contra
            dataFirstContra(:, a:a+29, :) = contraB(:, :, j);
            dataLastContra(:, a:a+29) = contraD(:, :, end-5+j);
            a = a + 30;
        end
    end
    % Gabor wavelet function, contra
    [gabor_responseFirst_contra] = gabor_response_span(dataFirstContra, cf(i), span(i), Fs);
    [gabor_responseLast_contra] = gabor_response_span(dataLastContra, cf(i), span(i), Fs);
    % Power envelope, contra
    power_envFirst_contra = squeeze(abs(gabor_responseFirst_contra).^2);
    power_envLast_contra = squeeze(abs(gabor_responseLast_contra).^2);
    
    % PCA
    % ipsi data
    [coeffF_ipsi, scoreF_ipsi, latentF_ipsi, tsquaredF_ipsi, explainedF_ipsi] = pca(power_envFirst_ipsi);
    [coeffL_ipsi, scoreL_ipsi, latentL_ipsi, tsquaredL_ipsi, explainedL_ipsi] = pca(alpha_power_envLast_ipsi);
    % contra data
    [coeffF_contra, scoreF_contra, latentF_contra, tsquaredF_contra, explainedF_contra] = pca(power_envFirst_contra);
    [coeffL_contra, scoreL_contra, latentL_contra, tsquaredL_contra, explainedL_contra] = pca(power_envLast_contra);
    
    % Find vars needed to explain 90% variance in each PCA function
    % FIRST 5 trials, contra
    EF_contra = zeros(size(explainedF_contra));
    for j = 1:numel(explainedF_contra)
        EF_contra(j) = sum(explainedF_contra(1:j));
        if (EF_contra(j) > 90)
            break
        end
    end
    EF_contra(EF_contra == 0) = []; %delete extra 0s
    % LAST 5 trials, contra
    EL_contra = zeros(size(explainedL_contra));
    for j = 1:numel(explainedL_contra)
        EL_contra(j) = sum(explainedL_contra(1:j));
        if (EL_contra(j) > 90)
            break
        end
    end
    EL_contra(EL_contra == 0) = []; %delete extra 0s
    
    % Plotting centriods
    % Center graph axes
    ax = gca;
    ax.XAxisLocation = 'origin'; %move X AXIS location to origin
    ax.YAxisLocation = 'origin'; %move Y AXIS location to origin
    hold on
    
    %%Separate PCA data into REST and MOVE (FIRST 5 sessions, contra)
    restDataPCAFirst_contra = scoreF_contra(1:150, :);
    moveDataPCAFirst_contra = scoreF_contra(151:300, :);
    %%Calc avg of each REST and MOVE COLUMN
    meanRestF_contra = mean(restDataPCAFirst_contra);
    meanMoveF_contra = mean(moveDataPCAFirst_contra);
    %%Constrain REST and MOVE to size of EF and EL
    meanRestF_contra = meanRestF_contra(1:numel(EF_contra));
    meanMoveF_contra = meanMoveF_contra(1:numel(EF_contra));
    
    %%REPEAT for LAST 5 sessions, contra
    
    %%Separate PCA data into REST and MOVE (LAST 5)
    restDataPCALast_contra = scoreL_contra(1:150, :);
    moveDataPCALast_contra = scoreL_contra(151:300, :);
    %%Calc avg of each REST and MOVE COLUMN
    meanRestL_contra = mean(restDataPCALast_contra);
    meanMoveL_contra = mean(moveDataPCALast_contra);
    %%Constrain REST and MOVE to size of EF and EL
    meanRestL_contra = meanRestL_contra(1:numel(EL_contra));
    meanMoveL_contra = meanMoveL_contra(1:numel(EL_contra));
    
    %%Calc distance between centroids
    distanceF_contra = norm(meanRestF_contra - meanMoveF_contra);
    distanceL_contra = norm(meanRestL_contra - meanMoveL_contra);
    %%Store calc'd distance in centDist
    centDist_temp_contra(1, i) = distanceF_contra; %FIRST 5 sessions = Row 1
    centDist_temp_contra(2, i) = distanceL_contra; %LAST 5 sessions = Row 2
    %%Calc change from FIRST to LAST 5 sessions
    centDist_ft_contra(i) = centDist_temp_contra(2, i) - centDist_temp_contra(1, i);
    
    %Plot change in ARAT against change in centroid
    scatter(centDist_ft_contra(i), ARATchange(i))
    title('Avg change in contralat ft band position v. ARAT change')
end
hold off 
