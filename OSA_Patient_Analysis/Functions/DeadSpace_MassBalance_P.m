%% Added dead space compartment to existing mass transfer model
function [P, fact1] = DeadSpace_MassBalance_P(V2,V1,t2,t1,PDO21,PAO21,pars)
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
PIO2 = yO2*(PB-PH2O);
VD_total = VD_spiro + VD_anatom;
fact1 = abs((V2-V1)./VD_total);
fact2 = (V2-V1)/dt;
% Inspiration
num1 = fact1.*(PIO2-PDO21) + PDO21;

% Expiration
num2 = fact1.*(PAO21-PDO21) + PDO21;
    
    % Inspiration
    if (fact2 >= 0)
        P = num1;
    else
    % Expiration
        P =  num2;
    end
end