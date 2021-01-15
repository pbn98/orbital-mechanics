% Assignment 2 : Planetary Explorer
clc
clear all
close all

%% Set path to default
path(pathdef);
% Add [...] folder to path
addpath(genpath('functions\'));
addpath(genpath('../Common\'));

% Conversion constants
DAY2SECS=24*3600;

% DATA

const = astroConstants([23 13 9]);
R_E = const(1);					% radius of the Earth                   [ km ]
muE = const(2);					% gravitational parameter of Earth      [ km^3/s^2 ]
J2 = const(3);					% second zonal armonic of earth         [ - ]
omega_e = deg2rad(15.04)/3600;  % angular velocity of Earth's rotation  [ rad/s ]
gw_longitude0 = 0;              % longitude of greenwhich   at time t0  [ rad ] 
Psr = 4.56e-6;                  % Solar radiation pressure at 1AU           [N/m^2]
NDAYS = 1200;                      % Number of days to propagate for perturbations [days]


%% Assigned orbit parameters
selection = 3;

switch selection
    case 1
        a = 40718;		% [km]	semi-major axis
        e = 0.6177; 	% [-]	eccentricity
        i = deg2rad(78.2195);	% [deg]	inclination
        RAAN = deg2rad(0);
        omega = deg2rad(40);
        f0 = deg2rad(0);
        hp = 15566.491;	% [km]	height of perigee
        t0 = 0;
        k = 1;
        m = 1;
        periods = 4;               % number of periods to plot

        date0 = [2021 01 01 00 00 00];  % Initial date at time t=0
        
        % SRP perturbation data
        Cr = 1.2;		% [-] reflectivity coefficient
        Am = 4;			% [m^2/kg] area-to-mass ratio
        
    case 2
        % Validation of SRP perturbation, data from Curtis Example 10.9
        % here we validate our model using only SRP as a perturbation
        a = 10085.44;
        e = 0.025422;
        i = deg2rad(88.3924);
        RAAN = deg2rad(45.3812);
        omega = deg2rad(227.493);
        f0 = deg2rad(343.427);
        date0 = jd2date(2438400.5);  % Initial date at time t=0
        k = 1;
        m = 1;
        periods = 4;               % number of periods to plot

        J2 = 0;                      % Overwrite J2 coefficient to test SRP
        t0 = 0;
        
        % model
        
        % SRP perturbation data
        Cr = 2;		% [-] reflectivity coefficient
        Am = 2;			% [m^2/kg] area-to-mass ratio
end


%% Calculate the semi-major axis of the repeating ground track

a_repeating = repeating_ground_track(m,k,muE,omega_e);

%% Calculate the semi-major axis of the perturbed repeating ground track

a_secular = repeating_ground_track(m, k, muE, omega_e, J2, R_E, e, i);

%% Create the state vectors from orbital parameters

% calculate the orbital periods
T = 2*pi*sqrt(a^3/muE);                         % Original
T_repeating = 2*pi*sqrt(a_repeating^3/muE);     % Repeating ground track
T_secular = 2*pi*sqrt(a_secular^3/muE);         % Repeating secular ground track for the perturbed secular orbit

%% Create time vectors

t = (0:60:periods*T);                    	% Original
t_repeating = (0:60:periods*T_repeating);	% Repeating ground track
t_secular = (0:60:periods*T_secular);    	% Repeating secular ground track for the perturbed secular orbit

%% create state vectors

state_vec = [a e i RAAN omega f0];                   % Original
state_vec_repeating = [a_repeating e i RAAN omega f0];           % Repeating ground track
state_vec_secular = [a_secular e i RAAN omega f0];   % Repeating ground track for the perturbed secular orbit

%% Compute RA, declination, lon and latitude
% Original
[alpha, delta, lon, lat] = groundtrack(state_vec, gw_longitude0, t, omega_e, muE, t0);

% Repeating unperturbed ground track
[alpha_repeating, delta_repeating, lon_repeating, lat_repeating] = groundtrack(state_vec_repeating, gw_longitude0, t_repeating, omega_e, muE, t0);

% Repeating perturbed ground track
[alpha_secular, delta_secular, lon_secular, lat_secular] = groundtrack(state_vec_secular,gw_longitude0,t_secular,omega_e, muE,t0, J2, R_E);

%% Plotting of the groundtracks

figure(1)

% Original
plot_groundtrack(lon,lat,'#77AC30');

% Repeating ground track
plot_groundtrack(lon_repeating,lat_repeating, 'r' );

% Perturbed secular ground track
plot_groundtrack(lon_secular, lat_secular, 'y');

legend ('Original', 'Start', 'End','Repeating Ground track', 'Start', 'End', 'Repeating Secular Ground track', 'Start', 'End', 'Orientation','horizontal','Location','northoutside' );

%%

% Initial conditions
kep0 = [a e i RAAN omega f0];
tspan = t0:100:NDAYS*DAY2SECS;

%% Get the perturbed orbital elements
[t_gauss,kep_gauss] = ORBITPROPAGATOR(t0,kep0,tspan,date0,J2,Cr,Psr,Am);

tStart = tic;

% Initial cartesian elements
[r0, v0] =  kep2car(a,e,i,RAAN,omega,f0,muE);


% Find out how much time the gaussian propagation took
tGAUSS = toc(tStart);

%% Solve with the cartesian elements
kepB = zeros(length(tspan),6);

tStart = tic;

[ri, vi] = propagator(r0,v0,muE,tspan,J2,R_E,date0,Cr,Psr,Am);

% Convert cartesian to keplerian
for i = 1:length(ri(:,1))
    
    [kepB(i,1),kepB(i,2),kepB(i,3),kepB(i,4),kepB(i,5),kepB(i,6)] = car2kep(ri(i,:),vi(i,:),muE);
end

% Find out how much time the cartesian propagation took
tCART = toc(tStart);


%% Filtering lower frequencies

% Cut-off period
Tfilter = 3*T;

% Number of points for the filtering window
nwindow = nearest( Tfilter / (sum(diff(t_gauss)) / (numel(t_gauss)-1) ) );

% Filter elements ( no unwrapping)
kep_filtered = movmean( kep_gauss,nwindow,1);

%% Compare the two solutions through plotting
% wrapping

figure(2)

% Add a gap to cartesian elements to avoid numerical problems
kepB(:,3:5) = unwrap(kepB(:,3:5),[],1);
kepB(5:end,6) = unwrap(kepB(5:end,6),[],1);

kep_gauss(:,3:6) = unwrap(kep_gauss(:,3:6),[],1);

kep_filtered(:,3:6) = unwrap(kep_filtered(:,3:6),[],1);

kepB(:,3:6) = rad2deg(kepB(:,3:6));
kep_gauss(:,3:6) = rad2deg(kep_gauss(:,3:6));
kep_filtered(:,3:6) = rad2deg(kep_filtered(:,3:6));

tspan = tspan./DAY2SECS;
LINEWIDTH = 2;

%% Plotting
% Semi-major axis
subplot(2,3,1)
plot(tspan,kep_gauss(:,1)-a,tspan,kepB(:,1)-a,tspan,kep_filtered(:,1)-a);
legend('Gauss equations','Cartesian','Secular (filtered)')
grid on
xlabel('${time [days]}$','Interpreter', 'latex','Fontsize', 14)
ylabel('$\mathbf{a [Km]}$','Interpreter', 'latex','Fontsize', 14)

% Eccentricity
subplot(2,3,2)
plot(tspan,kep_gauss(:,2)-e,tspan,kepB(:,2)-e,tspan,kep_filtered(:,2)-e);
legend('Gauss equations','Cartesian','Secular (filtered)')
grid on
xlabel('${time [days]}$','Interpreter', 'latex','Fontsize', 14)
ylabel('$\mathbf{e [-]}$','Interpreter', 'latex','Fontsize', 14)


% inclination
subplot(2,3,3)
plot(tspan,kep_gauss(:,3),tspan,kepB(:,3),tspan,kep_filtered(:,3));
legend('Gauss equations','Cartesian','Secular (filtered)')
grid on
xlabel('${time [days]}$','Interpreter', 'latex','Fontsize', 14)
ylabel('$\mathbf{i [deg]}$','Interpreter', 'latex','Fontsize', 14)

% RAAN
subplot(2,3,4)
plot(tspan,kep_gauss(:,4)-rad2deg(RAAN),tspan,kepB(:,4)-rad2deg(RAAN),tspan,kep_filtered(:,4)-rad2deg(RAAN));
legend('Gauss equations','Cartesian','Secular (filtered)')
grid on
xlabel('${time [days]}$','Interpreter', 'latex','Fontsize', 14)
ylabel('$\mathbf{\Omega  [deg]}$','Interpreter', 'latex','Fontsize', 14)

% omega
subplot(2,3,5)
plot(tspan,kep_gauss(:,5),tspan,kepB(:,5),tspan,kep_filtered(:,5));
legend('Gauss equations','Cartesian','Secular (filtered)')
grid on
xlabel('${time [days]}$','Interpreter', 'latex','Fontsize', 14)
ylabel('$\mathbf{\omega  [deg]}$','Interpreter', 'latex','Fontsize', 14)


% f
subplot(2,3,6)
plot(tspan,kep_gauss(:,6),tspan,kepB(:,6),tspan,kep_filtered(:,6));
legend('Gauss equations','Cartesian','Secular (filtered)')
grid on
xlabel('${time [days]}$','Interpreter', 'latex','Fontsize', 14)
ylabel('$\mathbf{f  [deg]}$','Interpreter', 'latex','Fontsize', 14)

%% Compare the difference between the two solutions through plotting
figure(3)

% Semi-major axis
subplot(2,3,1)
semilogy(tspan,abs((kep_gauss(:,1) - kepB(:,1)))./kep0(1));
grid on
xlabel('${time [days]}$','Interpreter', 'latex','Fontsize', 14)
ylabel('${|a_{Car} - a_{Gauss}| / a0 [-]}$','Interpreter', 'latex')

% Eccentricity
subplot(2,3,2)
semilogy(tspan,abs(kep_gauss(:,2) - kepB(:,2)));
grid on
xlabel('${time [days]}$','Interpreter', 'latex','Fontsize', 14)
ylabel('${|e_{Car} - e_{Gauss}| [-]}$','Interpreter', 'latex')


% inclination
subplot(2,3,3)
semilogy(tspan,abs(kep_gauss(:,3) - kepB(:,3)) ./(2*pi));
grid on
xlabel('${time [days]}$','Interpreter', 'latex','Fontsize', 14)
ylabel('${|i_{Car} - i_{Gauss}| / 2\pi [-]}$','Interpreter', 'latex')

% RAAN
subplot(2,3,4)
semilogy(tspan,abs(kep_gauss(:,4) - kepB(:,4)) ./(2*pi));
grid on
xlabel('${time [days]}$','Interpreter', 'latex','Fontsize', 14)
ylabel('${|\Omega_{Car} - \Omega_{Gauss}| / 2\pi [-]}$','Interpreter', 'latex')

% omega
subplot(2,3,5)
semilogy(tspan,abs(kep_gauss(:,5) - kepB(:,5)) ./(2*pi));
grid on
xlabel('${time [days]}$','Interpreter', 'latex','Fontsize', 14)
ylabel('${|\omega_{Car} - \omega_{Gauss}| / 2\pi [-]}$','Interpreter', 'latex')


% omega
subplot(2,3,6)
semilogy(tspan,abs(kep_gauss(:,6) - kepB(:,6)) ./ kep0(5));
grid on
xlabel('${time [days]}$','Interpreter', 'latex','Fontsize', 14)
ylabel('${|f_{Car} - f_{Gauss}| / f_{Gauss} [-]}$','Interpreter', 'latex')

%% Plot from TLEs
% figure(4)
%
% [DATES, KEP]=readTLE('debris5.tle', 0);
%
% KEP(:,3:5) = unwrap(KEP(:,3:5),[],1);
% KEP(5:end,6) = unwrap(KEP(5:end,6),[],1);
%
% KEP(:,3:6) = rad2deg(KEP(:,3:6));
% % Semi-major axis
% subplot(2,3,1)
%
% plot(datenum(DATES),KEP(:,1));
% legend('TLEs')
% grid on
% xlabel('${time [T]}$','Interpreter', 'latex','Fontsize', 14)
% ylabel('$\mathbf{a [Km]}$','Interpreter', 'latex','Fontsize', 14)
%
% % Eccentricity
% subplot(2,3,2)
% plot(datenum(DATES),KEP(:,2));
% legend('TLEs')
% grid on
% xlabel('${time [T]}$','Interpreter', 'latex','Fontsize', 14)
% ylabel('$\mathbf{e [-]}$','Interpreter', 'latex','Fontsize', 14)
%
%
% % inclination
% subplot(2,3,3)
% plot(datenum(DATES),KEP(:,3));
% legend('TLEs')
% grid on
% xlabel('${time [T]}$','Interpreter', 'latex','Fontsize', 14)
% ylabel('$\mathbf{i [deg]}$','Interpreter', 'latex','Fontsize', 14)
%
% % RAAN
% subplot(2,3,4)
% plot(datenum(DATES),KEP(:,4));
% legend('TLEs')
% grid on
% xlabel('${time [T]}$','Interpreter', 'latex','Fontsize', 14)
% ylabel('$\mathbf{\Omega  [deg]}$','Interpreter', 'latex','Fontsize', 14)
%
% % omega
% subplot(2,3,5)
% plot(datenum(DATES),KEP(:,5));
% legend('TLEs')
% grid on
% xlabel('${time [T]}$','Interpreter', 'latex','Fontsize', 14)
% ylabel('$\mathbf{\omega  [deg]}$','Interpreter', 'latex','Fontsize', 14)
%
%
% % f
% subplot(2,3,6)
% plot(datenum(DATES),KEP(:,6));
% legend('TLEs')
% grid on
% xlabel('${time [T]}$','Interpreter', 'latex','Fontsize', 14)
% ylabel('$\mathbf{f  [deg]}$','Interpreter', 'latex','Fontsize', 14)