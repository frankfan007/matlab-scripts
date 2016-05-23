%
% this = CarIMM(nObsSt, nSt, st0, cov0, f1, f2, Q1, Q2, rCov, TPM)
%   [] = mmPredict()
%   [] = mmUpdate(hCell, assignedZ)

classdef CarIMM < handle
    properties
        %% For internal use 
        TPM % Transition Probability Matrix
        
        mmPredSt  % Mode Matched Predictions of States
        mmPredCov % Mode Matched Predictions of Covariances
         
        mmMixSt   % Mixing State
        mmMixCov  % Mixing Covariance 
        mixWeights % Mixing Weights for output
        
        mmUpSt   % Mode Matched Updates of States
        mmUpCov  % Mode Matched Updates of Covariances
        
        f1       % Motion modell 1
        f2       % Motion modell 2
        
        ukf1     % ukf filter for model 1
        ukf2     % ukf filter for model 2
        
        %% For output only
        upSt % Updated state estimate
        upCov % Updated covariance estimate
        
    end    
    methods        
        function this = CarIMM(nObsSt, nSt, st0, cov0, f1, f2, Q1, Q2, rCov, TPM)
            % Initializes the IMM filter as well as the underlying UKF's
            % that it will use.
            
            this.TPM = TPM;
            this.f1  = f1;
            this.f2  = f2;
            
            % Set intial state and covariance 
            [r, c] = size(cov0);
            this.mmUpCov = zeros(r,c,2);
            
            this.mmUpCov(:,:,1) = cov0;
            this.mmUpCov(:,:,2) = cov0;
            
            this.mmUpSt = [st0 st0];
            
            % Allocate space for predicted Covs and States 
            this.mmPredCov = zeros(r,c,2);
            
            [r, ~] = size(st0);
            this.mmMixSt = zeros(r, 2);                        
            this.mmPredSt = zeros(r, 2);                        
            
            
            % Initialize UKFs for each model 
            this.ukf1 = UKF(Q1, rCov, nObsSt, nSt, st0, cov0);
            this.ukf2 = UKF(Q2, rCov, nObsSt, nSt, st0, cov0);
            
            this.mixWeights = [0.5 0.5];
            
        end
        
        function [] = mmPredict(this)
            % Performs mixing as well as making a mode matched prediction
            % update
            
            %% Begin mixing
            mu(1,1) = this.TPM(1,1)*this.mixWeights(1)./ (this.TPM(1,1)*this.mixWeights(1) + this.TPM(2,1)*this.mixWeights(2));
            
            mu(1,2) = this.TPM(1,2)*this.mixWeights(1)./ (this.TPM(1,2)*this.mixWeights(1) + this.TPM(2,2)*this.mixWeights(2));
            
            mu(2,1) = this.TPM(2,1)*this.mixWeights(2)./ (this.TPM(1,1)*this.mixWeights(1) + this.TPM(2,1)*this.mixWeights(2));
            
            mu(2,2) = this.TPM(2,2)*this.mixWeights(2)./ (this.TPM(1,2)*this.mixWeights(1) + this.TPM(2,2)*this.mixWeights(2));

            
            this.mmMixSt(:,1) = mu(1,1)*this.mmUpSt(:,1) + mu(2,1)*this.mmUpSt(:,2);                        
                
                stDiff1 = this.mmUpSt(:,1) - this.mmMixSt(:,1);
                stDiff2 = this.mmUpSt(:,2) - this.mmMixSt(:,1);
                
            this.mmMixCov(:,:,1) = mu(1,1)*(this.mmUpCov(:,:,1) + (stDiff1)*(stDiff1)')...
                                 + mu(2,1)*(this.mmUpCov(:,:,2) + (stDiff2)*(stDiff2)');
            %
            this.mmMixSt(:,2) = mu(1,2)*this.mmUpSt(:,1) + mu(2,2)*this.mmUpSt(:,2);
            
                stDiff1 = this.mmUpSt(:,1) - this.mmMixSt(:,2);
                stDiff2 = this.mmUpSt(:,1) - this.mmMixSt(:,2);
                
            this.mmMixCov(:,:,2) = mu(1,2)*(this.mmUpCov(:,:,1) + (stDiff1)*(stDiff1)')...
                                 + mu(2,2)*(this.mmUpCov(:,:,2) + (stDiff2)*(stDiff2)');            
            
            %% Perform prediction
            
            this.ukf1.predictMoments(this.f1, this.mmMixSt(:,1), this.mmMixCov(:,:,1));
            this.ukf2.predictMoments(this.f2, this.mmMixSt(:,2), this.mmMixCov(:,:,2));
            
            % Store UKF predicted states and covariances 
            this.mmPredSt(:,1) = this.ukf1.predSt;
            this.mmPredSt(:,2) = this.ukf2.predSt;
            
            this.mmPredCov(:,:,1) = this.ukf1.predCov;
            this.mmPredCov(:,:,2) = this.ukf2.predCov;
        end
        
        function [] = mmUpdate(this, hCell, assignedZ)
            % Performs a mode matched update for each mode
            this.ukf1.updateMoments(hCell{1}, assignedZ);
            this.ukf2.updateMoments(hCell{2}, assignedZ);
            
            upSt1  = this.ukf1.upSt;
            upCov1 = this.ukf1.upCov;
            yPred1 = this.ukf1.yPred;
            S1     = this.ukf1.S;
            
            upSt2  = this.ukf2.upSt;
            upCov2 = this.ukf2.upCov;
            yPred2 = this.ukf2.yPred;
            S2     = this.ukf2.S;
                        
                        
            yPred1 = reshape(yPred1, 2*length(yPred1),1);            
            yPred2 = reshape(yPred2, 2*length(yPred2),1);
                                    
            
            w1 = mvnpdf(assignedZ, yPred1, S1)...
                *(this.TPM(1,1)*this.mixWeights(1) + this.TPM(2,1)*this.mixWeights(2));
            
            w2 = mvnpdf(assignedZ, yPred2, S2)...
                *(this.TPM(1,2)*this.mixWeights(1) + this.TPM(2,2)*this.mixWeights(2));
            
            if w1 == 0
                w1 = 0.01;
                w2 = 0.99;
            elseif w2 == 0
                w2 = 0.01;
                w1 = 0.99;
            end
            
            this.mixWeights = [w1 w2]./(w1 + w2); % Normalize and save
            
            this.mmUpSt(:,1) = upSt1;
            this.mmUpSt(:,2) = upSt2;
            
            this.mmUpCov(:,:,1) = upCov1;
            this.mmUpCov(:,:,2) = upCov2;
            
            this.upSt  = this.mixWeights(1)*upSt1 + this.mixWeights(2)*upSt2;
            this.upCov = this.mixWeights(1)*(upCov1 + (upSt1 - this.upSt)*(upSt1 - this.upSt)')...
                        +this.mixWeights(2)*(upCov2 + (upSt2 - this.upSt)*(upSt2 - this.upSt)'); 
            
        end                
        
    end
    
end









