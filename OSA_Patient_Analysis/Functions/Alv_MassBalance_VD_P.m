%% Adjusted mass transfer model to account for dead space
function P = Alv_MassBalance_VD_P(V2,V1,t2,t1,PcO2,PAO21,PDO21,pars)
% Physiological parameters
    yO2 = pars(1); 
    PB = pars(2); 
    PH2O = pars(3);
    R = pars(4);  
    T = pars(5); 
    Beta_p = pars(6);
    k = pars(7);
    VD_spiro = pars(8);
    VD_anatom = pars(9);
     
% Alveolar mass balance
dt = t2-t1;
V2_shift = V2 - VD_anatom; V1_shift = V1 - VD_anatom;
fact1 = (V2_shift-V1_shift)./V1_shift;
fact2 = (V2_shift-V1_shift)/dt;
coeff = k*R*T*dt*Beta_p./V1_shift;
% Inspiration
num1 = fact1.*(PDO21-PAO21) - coeff.*(PAO21-PcO2) + PAO21;

% Expiration
num2 = -coeff.*(PAO21-PcO2) + PAO21;
    
    % Inspiration
    if (fact2 >= 0)
        P = num1;
    else
    % Expiration
        P =  num2;
    end
end