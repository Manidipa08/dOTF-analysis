function SWIFT_TEZ_App2
   %Refer to the Matlab documentation(help) for the informations regarding the
   %buttons and the command syntax used to make the app

    global psf1 psf2 dark_frame;%to have the access to use them throughout the script
    global phase_upper phase_lower;%to have the access to use them throughout the script

   

    %GUI of the app
    hFig = uifigure('Name', 'SWIFT-TEZ', 'Position', [100, 100, 1000, 700]);
    uialert(hFig, 'Hello! Welcome to SWIFT-TEZ, an app where you can analyze PSF files and calculate wavefront errors.', 'Welcome');
    %we will be using two tab windows in the app, one will deal with file
    %management and feedback of the app working and another will be
    %analysing the data and generating outputs
    
    hTabGroup = uitabgroup(hFig, 'Position', [10, 10, 1180, 680]);%MATLAB documentation uitabgroup


    hTabcreate = uitab(hTabGroup, 'Title', 'File Management');
    uilabel(hTabcreate, 'Text', 'Normal PSF File:', 'Position', [20, 620, 100, 20]);
    hNormalPSF = uieditfield(hTabcreate, 'text', 'Position', [130, 620, 300, 22]);
    uibutton(hTabcreate, 'Text', 'Browse', 'Position', [440, 620, 80, 22], ...
        'ButtonPushedFcn', @(~, ~) browseFile(hNormalPSF, 1));
    uilabel(hTabcreate, 'Text', 'Poked PSF File:', 'Position', [20, 580, 120, 20]);
    hModifiedPSF = uieditfield(hTabcreate, 'text', 'Position', [130, 580, 300, 22]);
    uibutton(hTabcreate, 'Text', 'Browse', 'Position', [440, 580, 80, 22], ...
        'ButtonPushedFcn', @(~, ~) browseFile(hModifiedPSF, 2));
    uilabel(hTabcreate, 'Text', 'Dark File:', 'Position', [20, 540, 100, 20]);
    hDarkFile = uieditfield(hTabcreate, 'text', 'Position', [130, 540, 300, 22]);
    uibutton(hTabcreate, 'Text', 'Browse', 'Position', [440, 540, 80, 22], ...
        'ButtonPushedFcn', @(~, ~) browseDarkFile(hDarkFile));
    logo_img = uiimage(hTabcreate, 'Position', [630, 390, 260, 260]);
    logo_img.ImageSource = 'SWIFT_TEZ.png';
    %adding user guide
    user_img = uiimage(hTabcreate, 'Position', [10, 70, 500, 300]);
    user_img.ImageSource = 'userrr_guide.png';
    uilabel(hTabcreate, 'Text', 'Command Feedback Window:', 'Position', [20, 500, 200, 20]);
    hFeedback = uitextarea(hTabcreate, 'Position', [20, 400, 500, 90], 'Editable', 'off');


    hTabdata = uitab(hTabGroup, 'Title', 'Data Analysis');
    ax1 = uiaxes(hTabdata, 'Position', [20, 350, 300, 300]);
    ax2 = uiaxes(hTabdata, 'Position', [350, 350, 300, 300]);
    ax3 = uiaxes(hTabdata, 'Position', [680, 350, 300, 300]);
    ax4 = uiaxes(hTabdata, 'Position', [680, 30, 300, 300]);
    uilabel(hTabdata, 'Text', 'Mask Radius (px):', 'Position', [20, 300, 100, 20]);
    hMaskRadius = uieditfield(hTabdata, 'numeric', 'Position', [130, 300, 100, 22], 'Value', 50);
    uilabel(hTabdata, 'Text', 'No. of zernike coefficients:', 'Position', [20, 260, 160, 20]);
    zernikeCof = uieditfield(hTabdata, 'numeric', 'Position', [180, 260, 100, 22], 'Value', 12);
    uibutton(hTabdata, 'Text', 'Run dOTF Analysis', 'Position', [20, 200, 150, 30], ...
        'ButtonPushedFcn', @(~, ~) runDOTF(ax1, ax2, ax3, ax4, hMaskRadius, hFeedback));
    uibutton(hTabdata, 'Text', 'Calculate Zernike Coefficients', 'Position', [20, 90, 200, 30], ...
        'ButtonPushedFcn', @(~, ~) ZernikeCoefficient_and_Save(zernikeCof, hFeedback));
    uibutton(hTabdata, 'Text', 'Change ColorMap', 'Position', [20, 145, 150, 30], ...
        'ButtonPushedFcn', @(btn, event) changeColormap());
       
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    function browseFile(hEdit, psfInd)
        [file, path] = uigetfile('*.fits', sprintf('Select PSF%d Image', psfInd));
        if isequal(file, 0)
            return;
        end
        if psfInd == 1
            psf1 = fitsread(fullfile(path, file));
        else
            psf2 = fitsread(fullfile(path, file));
        end
        hEdit.Value = fullfile(path, file);
        hFeedback.Value = [hFeedback.Value; {sprintf('Selected PSF%d file: %s', psfInd, file)}];
    end
    function browseDarkFile(hEdit)
        [file, path] = uigetfile('*.fits', 'Select the Dark Frame');
        if isequal(file, 0)
            return;
        end
        dark_frame = fitsread(fullfile(path, file));
        hEdit.Value = fullfile(path, file);
        hFeedback.Value = [hFeedback.Value; {sprintf('Selected dark file: %s', file)}];
    end



    function changeColormap()
        cmap = uisetcolormap;
        colormap(ax1, cmap);
        colormap(ax2, cmap);
        colormap(ax3, cmap);
        colormap(ax4, cmap);
    end




    %dOTF calculation and implemented on the OTFs obtained from the fft of
    %PSfs
    function runDOTF(ax1, ax2, ax3, ax4, maskRadiusField, feedback)%no central obscuration implemented 
        if isempty(dark_frame) || isempty(psf1) || isempty(psf2)
            uialert(hFig, 'Please load all the files.', 'Error');
            return;
        end

        psf1_sub = double(psf1) - double(dark_frame);
        psf2_sub = double(psf2) - double(dark_frame);
        psf1_center = cenP(psf1_sub);
        psf2_center = cenP(psf2_sub);
        cropS = 500; 
        psf1_cropped = cropP(psf1_center, cropS);
        psf2_cropped = cropP(psf2_center, cropS);
        otf1 = fftshift(fft2((psf1_cropped)));%zero frequency to the center
        otf2 = fftshift(fft2((psf2_cropped)));%zero frequency to the center
        dotf = otf2 - otf1;         
        dotf_mag = abs(dotf);
        %wavefront error(phase measurements in wavelength)
        lambda = 632e-9; % Wavelength in meters
        wf = angle(dotf)*(lambda / (2 * pi))%refering to the literature 
         

   
        dim = size(dotf, 1);  % Dimension of dotf (500x500)
        maskRadius = maskRadiusField.Value;  % Pupil Radius(px)
        pupil_mask = mkpup(dim, maskRadius);
        upper_mask = zeros(size(dotf));
        lower_mask = zeros(size(dotf));
        upper_mask(1:floor(dim / 2), :) = pupil_mask(1:floor(dim / 2), :);  % Upper pupil mask
        lower_mask(floor(dim / 2):end, :) = pupil_mask(floor(dim / 2):end, :);  % Lower pupil mask
        dotf_p_upper = dotf .* upper_mask;  % Apply mask to upper pupil
        dotf_p_lower = dotf .* lower_mask;  % Apply mask to lower pupil
        phase_upper = angle(dotf_p_upper) * (lambda / (2 * pi));
        phase_lower = angle(dotf_p_lower) * (lambda / (2 * pi));




        setappdata(hFig, 'phase_upper', phase_upper);
        setappdata(hFig, 'phase_lower', phase_lower);


        % Used log scale for better image quality(ax1, ax2)
        imagesc(ax1, log10(abs(psf1_cropped)+1)); 
        title(ax1, 'Centered PSF1'); 
        colormap(ax1, gray);
        imagesc(ax2, log10(abs(psf2_cropped)+1)); 
        title(ax2, 'Centered PSF2'); 
        colormap(ax2, gray);
        imagesc(ax3, dotf_mag); 
        title(ax3, 'dOTF'); 
        colormap(ax3, gray); 
        imagesc(ax4, wf); 
        title(ax4, 'Wavefront Error Map'); 
        colormap(ax4, gray);
   
        
        feedback.Value = [feedback.Value; {'dOTF Analysis Completed.'}];
        
    end


%Now we are decomposing the masked phase(either the upper or lower
%phase)into zernike coefficients and load them to .txt file
    function ZernikeCoefficient_and_Save(zernikecoffield, feedback)
         try
         phase_upper = getappdata(hFig, 'phase_upper');%retriving the stored data for the phases 
         phase_lower = getappdata(hFig, 'phase_lower');
         M= zernikecoffield.Value;
        [zernike_upper, fit] = zernike_coeffs_dOTF(phase_upper, M);%by default M = 12
        [zernike_lower, fit] = zernike_coeffs_dOTF(phase_lower, M)


        %saving the zernike coefficients for both the phases
        [file1, path1] = uiputfile('*.txt', 'Save Zernike Coefficients corresponds to Phase_Upper As');
        if isequal(file1, 0) || isequal(path1, 0)
            disp('User canceled the operation.');
            return;
        end   
        [file2, path2] = uiputfile('*.txt', 'Save Zernike Coefficients corresponds to Phase_Lower As');
        if isequal(file2, 0) || isequal(path2, 0)
            disp('User canceled the operation.');
            return;
        end
        Filename1 = fullfile(path1, file1);
        Filename2 = fullfile(path2, file2);


        writematrix(zernike_upper, Filename1, "Delimiter", "tab");
        writematrix(zernike_lower, Filename2, "Delimiter", "tab");
        disp(["Zernike coefficients saved in:", Filename1]);
        disp(["Zernike coefficients saved in:", Filename2]);             
        uialert(hFig, "The zernike coefficients files are saved successfully !", "Save successfully");

        feedback.Value = [feedback.Value; {'Zernike coefficients Analysis Completed.'}];
        
        catch ME
            uialert(hfig, "Error !!!!!","Warning");
            feedback.Value = [feedback.Value; {'Zernike coefficients Analysis interrupted.'}];
         end            
    end

    function centered_psf = cenP(psf)
    [row, col] = size(psf);
    [row_c, col_c] = find(psf == max(psf(:)));
    row_s = floor(row / 2) - row_c;
    col_s = floor(col / 2) - col_c;
    centered_psf = circshift(psf, [row_s, col_s]);
    end
    function cropped_psf = cropP(psf, crop)
    [row, col] = size(psf);
    row_cr = floor(row / 2) - floor(crop / 2) + 1;
    col_cr = floor(col / 2) - floor(crop / 2) + 1;
    cropped_psf = psf(row_cr:row_cr + crop - 1, col_cr:col_cr + crop - 1);
    end
    function pup = mkpup(dim, pupdim)%removed the central obscuration part(refer to the mkpup.m)
        [x, y] = meshgrid(1:dim, 1:dim);
        x = x - dim / 2 + 0.5; 
        y = y - dim / 2 + 0.5; 
        ratio = sqrt(x.^2 + y.^2) / (pupdim / 2);
        pup = (ratio <= 1);  % No central obscuration
    end

    
end
