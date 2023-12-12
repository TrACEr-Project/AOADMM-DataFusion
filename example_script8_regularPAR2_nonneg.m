%%  example script 8 AOADMM for CMTF 
% In this example, we create a synthetic regular PARAFAC2 tensor
% of order 3 (modes 1,2,3) and size [40,120,60] with 3 components  We add
% Gaussian noise with level 0.2 and use Frobenius norm loss.  
% All modes are constrained to be non-negative.
%%
close all
clear all
%% add AO-ADMM solver functions to path
addpath(genpath('.\functions'))
%% add other apckages to your path!
addpath(genpath('...\tensor_toolbox-v3.1')) %Tensor toolbox is needed!  MATLAB Tensor Toolbox. Copyright 2017, Sandia Corporation, http://www.tensortoolbox.org/
addpath(genpath('...\L-BFGS-B-C-master')) % LBFGS-B implementation only needed when other loss than Frobenius is used, download here: https://github.com/stephenbeckr/L-BFGS-B-C
addpath(genpath('...\proximal_operators\code\matlab')) % Proximal operator repository needed! download here: http://proximity-operator.net/proximityoperator.html
addpath(genpath('.\functions_for_example_scripts'))
%% specify synthetic data
sz     = {40,120*ones(1,60),60}; %size of each mode
P      = 1; %number of tensors
lambdas_data= {[1 1 1]}; % norms of components in each data set (length of each array specifies the number of components in each dataset)
modes  = {[1 2 3]}; % which modes belong to which dataset: every mode should have its unique number d, sz(d) corresponds to size of that mode
noise = 0.2; %level of noise, for gaussian noise only!
distr_data = {@(x,y) rand(x,y), @(x,y) rand(x,y),@(x,y) rand(x,y)+0.1}; % function handle of distribution of data within each factor matrix /or Delta if linearly coupled, x,y are the size inputs %coupled modes need to have same distribution! If not, just the first one will be considered
normalize_columns = 0; %wether or not to normalize columns of the created factor matrices, this might destroy the distribution!
%% specify tensor model
model{1} = 'PAR2';
%% specify couplings
coupling.lin_coupled_modes = [0 0 0]; % which modes are coupled, coupled modes get the same number (0: uncoupled)
coupling.coupling_type = []; % for each coupling number in the array lin_coupled_modes, set the coupling type: 0 exact coupling, 1: HC=Delta, 2: CH=Delta, 3: C=HDelta, 4: C=DeltaH
coupling.coupl_trafo_matrices = cell(3,1); % cell array with coupling transformation matrices for each mode (if any, otherwise keep empty)


%% set the fitting function for each dataset: 'Frobenius' for squared
% Frobenius norm, 'KL' for KL divergence, IS for Itakura-Saito, 'beta' for other beta divergences (give beta in loss_function_param),...more todo
loss_function{1} = 'Frobenius';
loss_function_param{1} = [];
%% check model
check_data_input(sz,modes,lambdas_data,coupling,loss_function,model);

%% set initialization options
init_options.lambdas_init = {[1 1 1]}; %norms of components in each data set for initialization
init_options.nvecs = 0; % wether or not to use cmtf_nvecs.m funcion for initialization of factor matrices Ci (if true, distr_data and normalize are ignored for Ci, not for Zi)
init_options.distr =distr_data; % distribution of the initial factor matrices and their auxiliary variables
init_options.normalize = 1; % wether or not to normalize the columns of the initial factor matrices (might destroy the distribution)

%% set constraints
constrained_modes = [1 1 1]; % 1 if the mode is constrained in some way, 0 otherwise, put the same for coupled modes!
prox_operators = cell(3,1); % cell array of length number of modes containing the function handles of proximal operator for each mode, empty if no constraint
% provide proximal operators for each constrained mode (operator should be a function, operating on the whole factor matrix, not just a single column)
% examples using functions from the Proximity Operator Repository:
% 1) Non-negativity: @(x,rho) project_box(x,0,inf);
% 2) Box-constraints with lower bound l and upper bound u: @(x,rho) project_box(x,l,u);
% 3) Simplex constraint column-wise (summing to eta): @(x,rho) project_simplex(x, eta, 1)
% 4) Simplex constraint row-wise (summing to eta): @(x,rho) project_simplex(x, eta, 2)
% 5) monotonicity constraint column-wise (non-decreasing): @(x,rho) project_monotone(x, 1)
% 6) monotonicity constraint column-wise (non-increasing): @(x,rho) -project_monotone(-x, 1)
% 7) (hard) l1 sparsity column-wise (||x||_1<=eta): @(x,rho) project_L1(x, eta, 1)
% 8) l2 normalization column-wise (||x||_2<=eta): @(x,rho) project_L2(x, eta, 1)
% 9) orthonormal columns of matrix x: @(x,rho) project_ortho(x)
% 9) l1 sparsity regularization (f(x)=eta*||x||_1):  @(x,rho) prox_abs(x,eta/rho*ones(size(x)))
% 10) l0 sparsity regularization (f(x)=eta*||x||_0): @(x,rho) prox_zero(x,eta/rho*ones(size(x))) (not convex!!!)
% 11) column-wise l2 regularization (f(x)=eta*||x||_2) : @(x,rho) prox_L2(x, eta/rho, 1)
% 12) quadratic smoothness regularization on factor matrix (f(X)=eta*||DX||_F^2): @(x,rho) (2*eta/rho*D'*D+eye(size(x)))\x

prox_operators{1} = @(x,rho) project_box(x,0,inf); % non-negativity
prox_operators{2} = @(x,rho) project_box(x,0,inf); % non-negativity
prox_operators{3} = @(x,rho) project_box(x,0,inf); % non-negativity
%% set regularization functions for each mode (corresponding to proximal operator for that mode) that should be included in the function value computation (optional)
%Z.reg_func = cell(3,1); % cell array of length number of modes containing the function handles of regularization functions for each mode, empty if no regularization; function should operate on the whole matrix
%Z.reg_func{1} =  @(x) 
%% add optional ridge regularization performed via primal variable updates, not proximal operators (for no ridge leave field empty), will automatically be added to function value computation
%Z.ridge = [1e-3,1e-3,1e-3,1e-3,1e-3,1e-3]; % penalties for each mode 
%% set weights
weights = [1]; %weight w_i for each data set

%% set lbfgsb options (only needed for loss functions other than Frobenius)
% lbfgsb_options.m = 5;
% lbfgsb_options.printEvery = -1;
% lbfgsb_options.maxIts = 100;
% lbfgsb_options.maxTotalIts = 1000;
% lbfgsb_options.factr = 1e-6/eps;
% lbfgsb_options.pgtol = 1e-4;

%% build model
Z.loss_function = loss_function;
Z.loss_function_param = loss_function_param;
Z.model = model;
Z.modes = modes;
Z.size  = sz;
Z.coupling = coupling;
Z.constrained_modes = constrained_modes;
Z.prox_operators = prox_operators;
Z.weights = weights;

%% create data
[X, Atrue, Deltatrue,sigmatrue] = create_coupled_data('model', model, 'size', sz, 'modes', modes, 'lambdas', lambdas_data, 'noise', noise,'coupling',coupling,'normalize_columns',normalize_columns,'distr_data',distr_data,'loss_function',Z.loss_function); %create data
%% create Z.object and normalize
normZ=cell(P,1);
for p=1:P
    Z.object{p} = X{p};
    if strcmp(model{p},'CP')
        normZ{p} = norm(Z.object{p});
        Z.object{p} = Z.object{p}/normZ{p};
    elseif strcmp(model{p},'PAR2')
        normZ{p} = 0;
        for k=1:length(Z.object{p})
            normZ{p} = normZ{p} + norm(Z.object{p}{k},'fro')^2;
        end
        normZ{p} = sqrt(normZ{p});
        for k=1:length(Z.object{p})
            Z.object{p}{k} = Z.object{p}{k}/normZ{p};
        end
    end
end

%% Create random initialization
init_fac = init_coupled_AOADMM_CMTF(Z,'init_options', init_options);

%% set options 

options.Display ='iter'; %  set to 'iter' or 'final' or 'no'
options.DisplayIters = 10;
options.MaxOuterIters = 4000;
options.MaxInnerIters = 5;
options.AbsFuncTol   = 1e-7;
options.OuterRelTol = 1e-8;
options.innerRelPrTol_coupl = 1e-5;
options.innerRelPrTol_constr = 1e-5;
options.innerRelDualTol_coupl = 1e-5;
options.innerRelDualTol_constr = 1e-5;
options.bsum = 0; % wether or not to use AO with BSUM regularization
%options.bsum_weight = 1e-3; %set the penalty parameter (mu) for BSUM regularization
options.eps_log = 1e-10; % for KL divergence log(x+eps) for numerical stability
%options.lbfgsb_options = lbfgsb_options;

%% run algorithm
fprintf('AOADMM cmtf \n')
tic
[Zhat,Fac,FacInit,out] = cmtf_AOADMM(Z,'alg_options',options,'init',init_fac,'init_options',init_options); 
toc
%% FIT
Fit1 = 0;
Fitx = 0;
for k=1:length(sz{2})
    Fit1 = Fit1 + norm(Z.object{1}{k}-Zhat{1}.A*diag(Zhat{1}.C(k,:))*Zhat{1}.Bk{k}','fro')^2;
    Fitx    = Fitx    + norm(Z.object{1}{k},'fro')^2;
end
Fit1 = 100*(1-Fit1/Fitx);
  
%% FMS 

FMS_A = score(ktensor(ones(3,1),Zhat{1}.A),ktensor(ones(3,1),Atrue{1}),'lambda_penalty',false);
FMS_C = score(ktensor(ones(3,1),Zhat{1}.C),ktensor(ones(3,1),Atrue{3}),'lambda_penalty',false);
SollargeB = [];
largeB = [];
for k=1:length(sz{2})
    SollargeB = [SollargeB;Zhat{1}.Bk{k}];
    largeB = [largeB;Atrue{2}{k}];
end
FMS_B = score(ktensor(ones(3,1),SollargeB),ktensor(ones(3,1),largeB),'lambda_penalty',false);
%% convergence plot
figure()
subplot(1,3,1)
semilogy([0:out.OuterIterations],out.func_val_conv)
hold on
semilogy([0:out.OuterIterations],out.func_constr_conv,':')
hold on
semilogy([0:out.OuterIterations],out.func_PAR2_coupl,'+')
xlabel('iterations')
ylabel('function value')
legend('function value','difference constraints','difference PAR2 coupling')


subplot(1,3,2)
semilogy(out.time_at_it,out.func_val_conv)
hold on
semilogy(out.time_at_it,out.func_constr_conv,':')
hold on
semilogy(out.time_at_it,out.func_PAR2_coupl,'+')
xlabel('time in seconds')
ylabel('function value')
legend('function value','difference constraints','difference PAR2 coupling')

markers = {'+','o','*','x','^','v','s','d','>','<','p','h'};
subplot(1,3,3)
for i=1:3
    plot(out.innerIters(i,:),markers{i})
    hold on
end
xlabel('outer iteration')
ylabel('inner iterations')
legend('mode 1', 'mode 2','mode 3')
sgtitle('convergence AO-ADMM')




