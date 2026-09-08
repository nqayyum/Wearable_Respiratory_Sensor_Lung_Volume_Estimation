Alv_MassBalance_VD.m was used in the oxygen mass transfer model for dissolved oxygen prediction. Contains the code for the alveolar mass transfer equations (adapted from *Qayyum NT, Wallace CH, Khayat RN and Grosberg A (2023) A mathematical model to serve as a clinical tool for assessing obstructive sleep apnea severity. Front. Physiol. 14:1198132. doi: 10.3389/fphys.2023.1198132* to incorporate effect of added dead space compartment)

Apnea_Refinement.m was used to automatically adjust boundaries of simulated apneas (performed breath holds) to account for any inaccuracies in the event annotations. This code was used in the signal processing section of RIP_Signal_Analysis_BE.m prior to lung volume prediction

Deadspace_MassBalance.m was used in the oxygen mass transfer model for dissolved oxygen prediction. Contains the code for the added dead space compartment mass transfer equations

Eupnea_Detection_Final.m was used to extract normal breaths from the specified normal breathing region at the beginning of each study. The extracted normal breaths were then used for the calibration of the lung volume prediction model(s)

ResFunction_final.m contains the residuals for each tested lung volume prediction equation solved using the least squares method in the main RIP_Signal_Analysis_BE.m code
  - Each equation has residuals for normal breathing and asynchronous breathing during simulated apneas, as well as less influential residuals implemented as soft penalties to ensure that the predicted lung volume is physiologically accurate
