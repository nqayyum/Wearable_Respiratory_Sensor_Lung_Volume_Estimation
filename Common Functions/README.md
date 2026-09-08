Asynchronous_Segment_Apnea.m was used to detect segments of asynchronous breathing during apneas/simulated apneas. The identified segments were used for the model calibration process for lung volume prediction
  - The identified segments were used as inputs for ResFunction_final.m, ResFunction_final_patient.m, and ResFunction_patient_Wake.m

Signal_Processing_Final.m was used to remove any non-physiological drift from apnea/simulated apnea segments and adjust the post-apnea segments
  - This function was used in the signal processing region of the RIP_Signal_Analysis_BE.m and RIP_Signal_Analysis_OSA.m codes prior to model calibration for lung volume prediction
