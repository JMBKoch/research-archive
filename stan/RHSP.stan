// 2 Factor Model, Cross-Loadings regularized with Regularized Horseshoe Prior

data{
  int<lower=0> N; // Sample Size
  int<lower=1> P; // Number of Outcomes/ items
  int<lower=1> Q; // Number of Factor
  matrix[N, P] Y; // outcome matrix
  real<lower=1> dfGlobal; // df for half-t prior omega
  real<lower=1> dfLocal; // df for half-t prior tau_j
  real<lower=0> scaleGlobal;
  real<lower=0> scaleLocal;
  real<lower=1> nu; // df IG for c^2
  real<lower=0> scaleSlab; // scale of slab (c^2)
}

parameters{
  vector[P] z;
  real<lower=0> tau; // global shrinkage parameter
  vector<lower=0>[P] omega; // local shrinkage parameters
  real<lower=0> caux; //
  
  vector<lower=0>[P] theta;
  vector[P] lambdaMain;
  real<lower=-1,upper=1> factCor;
}

transformed parameters{
  vector<lower=0>[P] omegaTilde; // truncated local shrinkage parameter
  real<lower=0> c; 
  
  vector[P] lambdaCross;
  matrix[P, Q] LambdaUnc;
  matrix[P, P] Theta;
  corr_matrix[Q] Psi;
  matrix[P, P] Sigma;
  vector[P] mu;
  
  c = scaleSlab * sqrt(caux);
  omegaTilde = sqrt( c^2*square(omega) ./ (c^2 + tau^2*square(omega)) ); 
  
  Theta = diag_matrix(theta);
  mu = rep_vector(0, P);
  
  lambdaCross = z .* omegaTilde*tau;

  // make loading matrix manually; TODO: automate
  LambdaUnc[1:3, 1] = lambdaMain[1:3];
  LambdaUnc[4:6, 2] = lambdaMain[4:6];
  
  LambdaUnc[4:6, 1] = lambdaCross[1:3];
  LambdaUnc[1:3, 2] = lambdaCross[4:6];
  
  // make Psi manually; todo: automate
  Psi[1, 1] = 1;
  Psi[2, 2] = 1;
  Psi[1, 2] = factCor;
  Psi[2, 1] = factCor;

  Sigma = LambdaUnc*Psi*LambdaUnc' + Theta;
}

model{
 //priors
 lambdaMain ~ normal(0, 5);
 theta ~ cauchy(0, 5);
 //helper variable
 z ~ normal(0, 1); 
 // default uniform prior on factCor

 // hyper-priors 
 omega  ~ student_t(dfLocal, 0, scaleLocal); // local (lambda)
 tau ~ student_t(dfGlobal, 0, scaleGlobal); // globale
 caux ~ inv_gamma(0.5*nu, 0.5*nu);
 
 //model
 for(i in 1:N)
   Y[i,] ~ multi_normal(mu, Sigma);
}

generated quantities{
  
  vector[P] lambdaMainC;
  vector[P] lambdaCrossC;
  corr_matrix[Q] PsiC; 

  PsiC = Psi;
  lambdaMainC = lambdaMain;
  lambdaCrossC = lambdaCross;

// factor 1 sign switching correction [p = 1, marker item]  
   if(lambdaMain[1] < 0){
     lambdaMainC[1:3] = -1*lambdaMain[1:3];
     lambdaCrossC[1:3] = -1*lambdaCross[1:3];

    if(lambdaMainC[4] > 0){ 
        PsiC[1, 2] = -1*Psi[1, 2];
        PsiC[2, 1] = -1*Psi[1, 2];
    }
}

// factor 2
   if(lambdaMain[4] < 0){
     lambdaMainC[4:6] = -1*lambdaMain[4:6];
    lambdaCrossC[4:6] = -1*lambdaCross[4:6];
     if(lambdaMain[1] > 0){
       PsiC[1, 2] = -1*Psi[1, 2];
       PsiC[2, 1] = -1*Psi[1, 2];
    }
  }
 
}