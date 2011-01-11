function GNFAC(varargin)  % -*-matlab-*-
% GNFAC updates the weather data listed on GNFAC website
%__________________________________________________________________________
% SYNTAX: GNFAC
%
% DESCRIPTION: 
%   GNFAC gathers data from the GNFAC website and archives the
%   data, this program should be run every hour to keep the data up-to-date
%   for the YCweather software.
%
% NOTES:
%   The varargin option is included to allow the function to be defined as
%   a handle.
%
% PROGRAM OUTLINE:
% 1 - DEFINE WEATHER STATION INFORMATION
% 2 - DETERMINE/CREATE CURRENT SEASON ARCHIVE FOLDER
% 3 - LOOP THROUGH EACH STATION AND COLLECT DATA
% SUBFUNCTION: appendfile
% SUBFUNCTION: readweb
% SUBFUNCTION: getfolder
% SUBFUNCTION: addyear
% SUBFUNCTION: read_gnfac
%__________________________________________________________________________

% 1 - DEFINE WEATHER STATION INFORMATION
    % 1.1 - Define GNFAC website, file extensions, and offline stations
        loc = 'http://www.mtavalanche.com/weather/';

    % 1.2 - Define the weather station website names and location codes
        name{1} = {'bridger/ridge','BBridge',1};
        name{2} = {'bridger/bridger','BBbridger',1};
        name{3} = {'bridger/alpine','BBalpine',1};
        name{4} = {'bridger/base','BBbase',1};
        
        name{5} = {'yellowstoneclub/timber','YCtimber',1};
        name{6} = {'yellowstoneclub/andesite','YCandesite',1};
        name{7} = {'yellowstoneclub/americanspirit','YCspirit',1};
        name{8} = {'yellowstoneclub/base','YCbase',1};
        
        name{9} = {'moonlight/jackcreek','MLjackcreek',1};
        name{10}= {'moonlight/lookout','MLlookout',1};
        name{11}= {'moonlight/greatfalls','MLgreatfalls',1};

        name{12}= {'lionhead','LHstation',1};
        
        name{13}= {'bigsky/challenger','BSchallenger',0};
        name{14}= {'bigsky/summit','BSsummit',1};
        name{15}= {'bigsky/bavaria','BSbavaria',1};
        
        
        
% 2 - DETERMINE/CREATE CURRENT SEASON ARCHIVE FOLDER
    fldr = [cd,filesep,'db',filesep,getfolder,filesep];
    if ~exist(fldr,'dir'); mkdir(fldr); end

% 3 - LOOP THROUGH EACH STATION AND COLLECT DATA
    for i = 1:length(name); 
    % 3.1 - Extract the data from web, ignore listed as offline
        data = readweb(loc,name{i});
        if isempty(data); continue; end
                     
    % 3.2 - Add year to challenger data
    if name{i}{3} == 1;
        data = addyear(data);
    end

    % 3.3 - Append data to the file        
        if ~isempty(data); 
            appendarchive(data,fldr,name{i});
        end
        
        pause(10); % Pause to not stress the servers
    end

disp(['Update successful: ',datestr(now)]);

%--------------------------------------------------------------------------
% SUBFUNCTION: appendfile
function appendarchive(data,fldr,name)
% APPENDARCHIVE adds latest data to existing file

% Set the filename and gather data from the old file
    [~,file] = fileparts(name{2});
    filename = [fldr,file,'.dat'];
   
% Create a file if it does not exist and open the file  
    if ~exist(filename,'file');
        dlmwrite(filename,data);
        %fid = fopen(filename,'a'); fclose(fid);
        return;
    end 
    old = dlmread(filename);

% Adjust data for size mismatches (i.e. station losses or gains readings)
    [r_old,c_old] = size(old); %c_new = cols(data);
    [r_new,c_new] = size(data);

    if c_old > c_new;
        tmp = NaN(r_new,c_old);
        tmp(:,1:c_new) = data;
        data = tmp;
    elseif c_new < c_old
        tmp = NaN(r_old,c_new);
        tmp(:,1:c_old) = data;
        data = tmp;
    end

    data(isnan(data)) = inf;    
    new = unique([old;data],'rows');
    new(isinf(new)) = NaN;
    dlmwrite(filename,new);

%--------------------------------------------------------------------------
% SUBFUNCTION: readweb
function data = readweb(loc,name)
% READWEB reads the website and stores html code in a *.txt file

% 1 - READ WEBSITE AND RETURN EMPTY VALUE IF FAILURE OCCURS
	try
        s = urlread([loc,name{1}]);
    catch
        warning('URL:failed',['Could not read url: ',loc,name{1}]);
        data = []; return;
    end

% 2 - SAVE THE DATA TO FILE
    data = read_gnfac(s);

%--------------------------------------------------------------------------
% SUBFUNCTION: getfolder
function fldr = getfolder
% GETFOLDER determines the current season/folder for archiving data

% 1 -  Get the current time
    c = clock;

% 2 - Determine the current folder based on water-year
    if c(2) < 10; % Case when before October
        yr2 = num2str(c(1));
        yr1 = num2str(c(1)-1);
        fldr = [yr1(3:4),'-',yr2(3:4)];
    
    else % Case when after Octoboer
        yr1 = num2str(c(1));
        yr2 = num2str(c(1)+1);
        fldr = [yr1(3:4),'-',yr2(3:4)];
    end

%--------------------------------------------------------------------------
% SUBFUNCTION: addyear
function data = addyear(in)
% ADDYEAR adds the current year to the data

% 1 - SEPERATE HOURS AND MINUTES
    N = size(in,1);
    hr = floor(in(:,3)/100);
    mn = in(:,3) - hr*100;

% 2 - SEARCH CURRENT DATA FOR THE NEW YEAR
    newyr = [];
    for i = 2:N;
        if in(i,1) == 1 && in(i-1,1) == 12; newyr = i-1; end
    end

% 3 - BUILD A YEAR COLUMN
    c = clock;  % current time
    if ~isempty(newyr); % case when new year is encountered
        yr(1:newyr) = c(1) - 1;
        yr(newyr+1:N) = c(1);
    else
        yr(1:N) = c(1);
    end

% 4 - RETURN DATA WITH LEADING YEAR COLUMN
    data = [yr',in];

%--------------------------------------------------------------------------
% SUBFUNCTION: read_gnfac
function data = read_gnfac(str)
% READ_GNFAC reads weather data from .shtml data file
%__________________________________________________________________________
% SYNTAX: data = read_gnfac(str)
%
% DESCRIPTION:
%   data = read_gnfac(str) reads the text file containing the html code
%       from the GNFAC weather website and returns the weather data in a
%       numeric array and appends the year to the beginning of the file
%
% PROGRAM OUTLINE:
% 1 - OPEN THE FILE AND EXTRACT TEXT
% 2 - DETERMINE THE LOCATION OF WEATHER DATA
% 3 - REMOVE EXTRA BLANK LINES IN DATA
% 4 - CONVERT TEXT INTO A NUMERIC ARRAY
% 5 - ADD YEAR TO DATA
% SUBFUNCTION: addyear
%__________________________________________________________________________

% 1 - CONVERT CHAR TO CELL ARRAY
    A = textscan(str,'%s','delimiter','\n'); A = A{1};

% 2 - DETERMINE THE LOCATION OF WEATHER DATA
    idx1 = strmatch('---',A);           % Beginning of data
    idx2 = strmatch('</pre></div>',lower(A));   % End of data
    idx3 = strmatch('page',lower(A));
    
% 3 - REMOVE EXTRA BLANK LINES IN DATA
    % 3.1 - Case for single page of data (i.e., idx3 is empty)
    if isempty(idx3);
        C = deblank(A(idx1(1)+1:idx2(1)-1));      % Removes extrenous whitespaces
        idx4 = strmatch('',C,'exact');
        if ~isempty(idx4);  
            C = C(1:idx4(1)-1);
        end
        
    % 3.2 - Case for multipage data    
    else
        C = {};
        for i = 1:length(idx1);
            c = deblank(A(idx1(i)+1:idx3(i)-1));      % Removes extrenous whitespaces    
            
            idx4 = strmatch('',c,'exact');
            if ~isempty(idx4);  
                C = [C; c(1:idx4(1)-1)];
            end
        
        end
    end

    % 3.3 - Return if no data was found
    if isempty(C); data = []; return; end
    
% 4 - CONVERT TEXT INTO A CHARACTER ARRAY
    N = length(C);
    for i = 1:N
        D = textscan(C{i},'%s'); d = D{1};
        raw(i,:) = D{1};
    end

% 5 - CONVERT COLUMNS INTO NUMERIC VALUES 
    % 5.1 - Correct for date and time columns in "mm/dd HH:MM" format
        if isnan(str2double(raw(:,1))); % Test 1st column        
            for i = 1:N;
                m1 = textscan(raw{i,1},'%f/%f');    % Read mm/dd
                m2 = textscan(raw{i,2},'%f:%f');    % Read HH:MM

                % Append weather data
                data(i,:) = [m1{1}, m1{2}, 100*m2{1}+m2{2},...
                                str2double(raw(i,3:size(raw,2)))];
            end
        
    % 5.2 - Case when data is in standard "mm dd HHMM" format
        else
            data = str2double(raw);
        end

% 6 - Remove NaN rows (N,W,... direction)
    ind = find(nansum(data,1) == 0);
    if ~isempty(ind);
        data = data(:,[1:ind-1,ind+1:end]);
    end
