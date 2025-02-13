function settings = Tracking_3D_From_File_refsystem(settings, part_file_txt)


%% Physical parameters

q  = settings.Z_n*1.602176565e-19;           % Charge [Coulomb]
m0 = settings.A_n*1.672621777e-27;           % Mass [kg]
c  = 299792458;                     % Speed of light [m/s]
eV_J = 1.602176565e-19;             % Ratio between eV and joule    

%% Read Input File
fid=fopen(part_file_txt,'r');

readFormat = '%f, %f, %f, %f, %f, %f, %f, %f, %f, %f, %f';
temp = textscan(fid,readFormat,'HeaderLines',1);
fclose(fid);

settings.ID = temp{7};                % Identification number

Xs1=[temp{1} temp{3} zeros(length(settings.ID),1)]; %x,y,z local coordinates [m]
pX=[temp{2} temp{4}]; %px,py local system
X00=[temp{9} temp{10} temp{11}]; %x,y,z global coordinate of ideal particle [m]

phi = temp{6};     %azimuthal angle [rad]
theta = temp{5};   %polar angle [rad]

E_k= settings.A_n*temp{8};            %beam kinetic energy [MeV]

settings.N = length(settings.ID);    %number of particles 

%% Calculation of velocities

%Calculation of the total energy [MeV]
E0 = m0*c^2 /eV_J /1e6;                         %Rest Energy: E0[eV] = mc^2 * (1eV / 1.602e-19 J) * (1MeV / 1e6 eV)
Etot_k = E0 + E_k;

%Calculation of the Momentum [MeV/c]            %Etot^2 = (mc^2)^2 + (Pc)^2 = E0^2 + (Pc)^2
P_k = sqrt(Etot_k.^2-E0^2); 

%Calculation of the Lorentz factor (Gamma)      %Etot[MeV] = mc^2 = Gamma*m0*c^2
Gamma_k = Etot_k./E0;
settings.qom = (q./(Gamma_k.*m0));               % Charge over mass

%Calculation of the velocity 
v_k = c*sqrt(1-1./(Gamma_k.^2));
settings.Br = P_k * 1e6 * eV_J / (c*q);

%% Rotation Matrix
t=1;

s=sin(pi/2-phi(t));
c=cos(pi/2-phi(t));
if abs(c)<1e-10
    c=0;
elseif abs(s)<1e-10
    s=0;
end
Mrx=[1 0 0; 0 c -s; 0 s c];

s=sin(theta(t));
c=cos(theta(t));
if abs(c)<1e-10
    c=0;
elseif abs(s)<1e-10
    s=0;
end
Mry=[c 0 -s; 0 1 0; s 0 c];
%% Input velocities - Spherical Coordinates to Cartesian

Vx=v_k.*[ cos(atan(pX(:,2))).*sin(atan(pX(:,1))) sin(atan(pX(:,2))) cos(atan(pX(:,1))).*cos(atan(pX(:,2)))]*sign(q);
V1=Vx*Mrx'*Mry';


%% Input coordiantes

Xt=Xs1*Mrx'*Mry';
X1=Xt+X00;
%% ODE solver

%Set initial values
X0 = [X1(:,1);X1(:,2);X1(:,3);V1(:,1);V1(:,2);V1(:,3)].';


% Set the simulation end time (distance/velocity)

tend=(0.75)/min(v_k);

if q<0
    tend =2*tend; 
end

% We can stop the integration when a given event occours
%event = @(t,X)myEvent(X,settings);

% Setting the precision for the solver
opts = odeset('AbsTol',1e-7,'RelTol',1e-7,'InitialStep',(1E-3)/max(v_k));       
%opts = odeset('AbsTol',1e-6,'RelTol',1e-6,'InitialStep',(1E-3)/max(v_k),'Events', event);        

fun = @(t,X)Motion_Eq_INFN(t,X,settings);

fprintf('Calculation of the Particle Trajectories . . . \n');
[t,X] = ode45(fun,[0,tend],X0,opts);
fprintf('Calculation of the Particle Trajectories COMPLETED \n');

settings.X = X;
settings.t = t;