% Class encapuslating and abstracting all classes and methods specific to
% elliptical targets.
%
% priors:
%       x0 - 6x1 kinematic state vector [xk, dxk, ddxk, yk, dyk, ddyk]
%       P0 - kinematic state covariance
%       v0 - random matrix shape Wishart degrees of freedom
%       V0 - random matrix shape Wishart scale matrix
% clusterZ - 3xN matrix
%
% Constructor
%           this = EllipTarget(x0, P0)
% Methods:
%             [] = predict()
%  [mant., exp.] = calcLikelihood(clusterZ) 
%             [] = update()
%  [upSt, upCov] = getState()
%
% Dependencies:
%  - giwMeasComp.m
%  - giwComp.m
%

classdef EllipTarget < handle
    properties      
        %motion model
        T       %sampling time
        theta   %maneuver correlation time (higher means smaller acceleration prediction)
        sigma   %scalar acceleration
        tau     %temporal decay (higher means smaller dof prediction)
        d
        F
        Q
        %meas model
        H
        R
        %state
        x
        P
        v
        V
        %elliptic target GIW-PHD parameters
        ps = 0.98;
        pd = 0.98;
        p_gamma = 250;
        p_beta = 1;
        %update components
        Khat
        Shat
        zhat
        S
        epsilon
    end
    
    methods
        %% Constructor
        function this = EllipTarget(x0, P0)
            % motion model
            this.T = 0.1;
            this.theta = 1;
            this.sigma = 2;
            this.tau = 5;
            this.d = 2;
            this.F = [  1      this.T  (1/2)*this.T^2;
                        0      1       this.T;
                        0      0       exp(-this.T/this.theta)];
            this.Q = this.sigma^2*(1-exp(-(2*this.T)/this.theta))*diag([0 0 1]);

            % measurement model
            this.H = [1 0 0];
            this.R = 0.00015*diag(ones(1,this.d));  
            
            % prior state
            this.x = x0;
            this.P = P0;
            this.v = 7;
            this.V = diag([1 1]);
        end
        
        %% API functions
        function [] = predict(this)
            this.x = kron(this.F,eye(this.d))*this.x;
            this.P = this.F*this.P*this.F' + this.Q;
            temp_v = this.v;
            this.v = exp(-this.T/this.tau)*this.v;
            this.V = ((this.v-this.d-1)/(temp_v-this.d-1)) .* this.V;            
        end
        
        function [mantissa, base10_exponent] = calcLikelihood(this, clusterZ)
            meas = giwMeasComp(clusterZ);
            this.Khat = this.P*this.H';
            this.Shat = this.H*this.Khat;                
            this.zhat = kron(this.H,eye(this.d))*this.x;
            this.S = this.Shat + 1/meas.n;
            this.epsilon = meas.center - this.zhat;
            
            N = (this.epsilon*this.epsilon')/this.S;
            newv = this.v + meas.n;
            newV = this.V + N + meas.scatter;
            
            %calculate new weight-scale as a log-likelihood 
            f1 = (-this.p_gamma*log(exp(1)) + n_points*log(this.p_gamma) + log(this.pd))...
                -(n_points*log(this.p_beta) + (this.d/2)*(n_points*log(pi) + log(n_points) + log(S)));
            f2 = ((this.v/2)*log(det(this.V)))...
                -((newv/2)*log(det(newV)));
            f3 = (gamma_2d_log(newv/2))...
                -(gamma_2d_log(this.v/2));
            logw_scale = f1+f2+f3;
            
            %update the shape with the new values
            this.v = newv;
            this.V = newV;
            
            %return the log likelihood as mantissa and base10 exponent
            [mantissa, base10_exponent] = base10_mantissa_exponent(exp(1),logw_scale);
        end
        
        function [] = update(this)
            K = this.Khat/this.S;
            this.x = this.x + kron(K,eye(this.d))*this.epsilon;
            this.P = this.P - K*this.S*K';
        end
        
        function [st, cov, dof, scale] = getState(this)
            st = this.x;
            cov = this.P;
            dof = this.v;
            scale = this.V;
        end
        
    end
end