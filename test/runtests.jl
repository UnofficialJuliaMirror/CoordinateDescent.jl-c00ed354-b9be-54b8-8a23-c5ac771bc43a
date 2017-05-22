using FactCheck

using HD
using ProximalBase

# function try_import(name::Symbol)
#     try
#         @eval import $name
#         return true
#     catch e
#         return false
#     end
# end

# grb = try_import(:Gurobi)
# cvx = try_import(:Convex)
# ipopt = try_import(:Ipopt)
# grb = false
#
# if grb
#   Convex.set_default_solver(Gurobi.GurobiSolver(OutputFlag=0))
# else
#   Convex.set_default_solver(Ipopt.IpoptSolver(print_level=0, tol=1e-12))
# end

##############################################
#
#  Lasso
#
##############################################

facts("lasso") do

  context("zero") do
    n = 100
    p = 10

    X = randn(n, p)
    Y = X * ones(p) + 0.1 * randn(n)
    Xy = X' * Y / n

    lambda = fill(maximum(abs.(Xy)) + 0.1, p)
    beta = HD.lasso(X, Y, lambda)
    @fact beta --> spzeros(p)
  end

  context("non-zero") do
    for i=1:100
      n = 100
      p = 10
      s = 5

      X = randn(n, p)
      Y = X[:,1:s] * ones(s) + 0.1 * randn(n)

      lambda = fill(0.3, p)
      beta = HD.lasso(X, Y, lambda, CDOptions(;optTol=1e-12))

      f = CDQuadraticLoss(X'X/n, -X'Y/n)
      g = ProximalBase.AProxL1(lambda)
      x1 = coordinateDescent(f, g, CDOptions(;optTol=1e-12))
      @fact beta --> roughly(x1; atol=1e-5)

      @fact maximum(abs.(X'*(Y - X*beta) / n)) <= 0.3 + 1e-5 --> true
    end
  end

end

facts("cd lasso") do

for i=1:100
  n = 200
  p = 50
  s = 10

  X = randn(n, p)
  β = randn(s)
  Y = X[:,1:s] * β + 0.1 * randn(n)

  g = ProximalBase.ProxL1(0.2)
  f1 = CDQuadraticLoss(X'X/n, -X'Y/n)
  f2 = CDLeastSquaresLoss(Y, X)

  x1 = coordinateDescent(f1, g, CDOptions(;optTol=1e-12))
  x2 = coordinateDescent(f2, g, CDOptions(;optTol=1e-12))

  @fact maximum(abs.(x1 - x2)) --> roughly(0.; atol=1e-5)
end

end


# ##############################################
# #
# #  Group Lasso Functionallity
# #
# ##############################################
#
# facts("prox l2 norm") do
#   context("shrink to zero") do
#     p = 10
#     x = randn(p)
#     hat_x = randn(p)
#     lambda = norm(x) + 0.1
#     prox_l2!(hat_x, x, lambda)
#     @fact hat_x --> roughly(zeros(Float64, p))
#     @fact hat_x --> zeros(Float64, p)
#
#     if cvx && grb
#       theta = Convex.Variable(p)
#       prob = Convex.minimize(Convex.sumsquares(theta - x) / 2 + lambda * norm(theta, 2))
#       Convex.solve!(prob)
#       @fact hat_x - vec(theta.value) --> roughly(zeros(Float64, p); atol=5e-4)
#     end
#   end
#
#   context("non-zero") do
#     # compare to Mosek output
#     p = 10
#     x = randn(p)
#     hat_x = randn(p)
#     lambda = 0.3
#     prox_l2!(hat_x, x, lambda)
#
#     if cvx && grb
#       theta = Convex.Variable(p)
#       prob = Convex.minimize(Convex.sumsquares(theta - x) / 2 + lambda * norm(theta, 2))
#       Convex.solve!(prob)
#       @fact hat_x - vec(theta.value) --> roughly(zeros(Float64, p); atol=5e-4)
#     end
#   end
# end
#
# facts("minimize one group") do
#   n = 100
#   p = 10
#
#   X = randn(n, p)
#   Y = X * ones(p) + 0.1 * randn(n)
#
#   XX = X' * X / n
#   Xy = X' * Y / n
#
#   context("non-zero") do
#     if cvx && grb
#       lambda = 0.3
#       theta = Convex.Variable(p);
#       prob = Convex.minimize(Convex.sumsquares(Y-X*theta) / (2*n) + lambda * norm(theta, 2))
#       Convex.solve!(prob)
#
#       beta = zeros(p)
#       HD.minimize_one_group_raw!(beta, X, Y, lambda)
#       @fact beta --> roughly(vec(theta.value); atol=5e-4)
#
#       beta = zeros(p)
#       HD.minimize_one_group!(beta, XX, Xy, lambda)
#       @fact beta --> roughly(vec(theta.value); atol=5e-4)
#     end
#   end
#
#   context("zero") do
#     if cvx && grb
#       lambda = norm(Xy) + 0.1
#
#       theta = Convex.Variable(p);
#       prob = Convex.minimize(Convex.sumsquares(Y-X*theta) / (2*n) + lambda * norm(theta, 2))
#       Convex.solve!(prob)
#
#       beta = zeros(p)
#       HD.minimize_one_group_raw!(beta, X, Y, lambda)
#       @fact beta --> roughly(vec(theta.value); atol=5e-4)
#
#       beta = zeros(p)
#       HD.minimize_one_group!(beta, XX, Xy, lambda)
#       @fact beta --> roughly(vec(theta.value); atol=5e-4)
#
#       beta = zeros(p)
#       HD.minimize_one_group!(beta, XX, Xy, lambda)
#       @fact beta --> zeros(Float64, p)
#     end
#   end
#
# end
#
# facts("compute_group_residual") do
#   n = 100
#   p = 10
#   X = randn(n, p)
#   Y = X * ones(p) + 0.1 * randn(n)
#   XX = X' * X / n
#   Xy = X' * Y / n
#
#   groups=Array(Array{Int64, 1}, 2)
#   groups[1] = 1:5
#   groups[2] = 6:10
#   active_set=[1,2]
#
#   res = zeros(Float64, 5)
#   k = 1
#   HD.compute_group_residual!(res, XX, Xy, zeros(p), groups, active_set, k)
#   @fact res --> roughly(Xy[groups[k]])
#
#   res = zeros(Float64, 5)
#   beta = [ones(5); zeros(5)]
#   k = 1
#   HD.compute_group_residual!(res, XX, Xy, beta, groups, active_set, k)
#   @fact res --> roughly(Xy[groups[k]])
#
#   res = zeros(Float64, 5)
#   beta = [ones(5); zeros(5)]
#   k = 2
#   HD.compute_group_residual!(res, XX, Xy, beta, groups, active_set, k)
#   @fact res --> roughly(-XX[groups[k],groups[1]]*beta[groups[1]]+Xy[groups[k]])
#
#   res = zeros(Float64, 5)
#   beta = [ones(5); ones(5)]
#   k = 2
#   HD.compute_group_residual!(res, XX, Xy, beta, groups, active_set, k)
#   @fact res --> roughly(-XX[groups[k],groups[1]]*beta[groups[1]]+Xy[groups[k]])
#
#   res = zeros(Float64, 5)
#   beta = [zeros(5); ones(5)]
#   k = 1
#   HD.compute_group_residual!(res, XX, Xy, beta, groups, active_set, k)
#   @fact res --> roughly(-XX[groups[k],groups[2]]*beta[groups[2]]+Xy[groups[k]])
# end
#
#
# facts("minimize_active_groups") do
#   n = 100
#   p = 10
#   X = randn(n, p)
#   Y = X * ones(p) + 0.1 * randn(n)
#   XX = X' * X / n
#   Xy = X' * Y / n
#
#   context("one active set") do
#     groups=Array(Array{Int64, 1}, 2)
#     groups[1] = collect(1:5)
#     groups[2] = collect(6:10)
#     active_set=[1]
#
#     lambda = maximum(map((x)->norm(Xy[x]), groups)) + 0.1
#     lambda = [lambda, lambda]
#     beta = zeros(p)
#     HD.minimize_active_groups!(beta, XX, Xy, groups, active_set, lambda)
#     @fact beta --> zeros(p)
#
#     lambda = [0.3, 0.6]
#     beta = zeros(p)
#     HD.minimize_active_groups!(beta, XX, Xy, groups, active_set, lambda)
#
#     if cvx && grb
#       theta = Convex.Variable(5)
#       prob = Convex.minimize(Convex.sumsquares(Y-X[:,1:5]*theta) / (2*n) + lambda[1] * norm(theta, 2))
#       Convex.solve!(prob)
#
#       @fact beta[1:5] - vec(theta.value) --> roughly(zeros(Float64, 5), 1e-3)
#
#       active_set = [2]
#       beta = zeros(p)
#       HD.minimize_active_groups!(beta, XX, Xy, groups, active_set, lambda)
#
#       theta = Convex.Variable(5)
#       prob = Convex.minimize(Convex.sumsquares(Y-X[:,6:10]*theta) / (2*n) + lambda[2] * norm(theta, 2))
#       Convex.solve!(prob)
#
#       @fact beta[6:10] - vec(theta.value) --> roughly(zeros(Float64, 5), 1e-3)
#     end
#   end
#
#   context("two active sets") do
#     groups=Array(Array{Int64, 1}, 2)
#     groups[1] = collect(1:5)
#     groups[2] = collect(6:10)
#     active_set=[1, 2]
#
#     lambda_max = maximum(map((x)->norm(Xy[x]), groups)) + 0.1
#     lambda = [lambda_max, lambda_max]
#     beta = zeros(p)
#     HD.minimize_active_groups!(beta, XX, Xy, groups, active_set, lambda)
#     @fact beta --> zeros(p)
#
#     lambda = [0.3, lambda_max]
#     beta = zeros(p)
#     HD.minimize_active_groups!(beta, XX, Xy, groups, active_set, lambda)
#
#     if cvx && grb
#       theta = Convex.Variable(10)
#       prob = Convex.minimize(Convex.sumsquares(Y-X*theta) / (2*n) + lambda[1] * norm(theta[1:5], 2) + lambda[2] * norm(theta[6:10], 2))
#       Convex.solve!(prob)
#
#       @fact beta - vec(theta.value) --> roughly(zeros(Float64, 10), 1e-3)
#
#       lambda = [lambda_max, 0.6]
#       beta = zeros(p)
#       HD.minimize_active_groups!(beta, XX, Xy, groups, active_set, lambda)
#
#       theta = Convex.Variable(10)
#       prob = Convex.minimize(Convex.sumsquares(Y-X*theta) / (2*n) + lambda[1] * norm(theta[1:5], 2) + lambda[2] * norm(theta[6:10], 2))
#       Convex.solve!(prob)
#
#       @fact beta - vec(theta.value) --> roughly(zeros(Float64, 10), 1e-3)
#
#       lambda = [0.3, 0.6]
#       beta = zeros(p)
#       HD.minimize_active_groups!(beta, XX, Xy, groups, active_set, lambda)
#
#       theta = Convex.Variable(10)
#       prob = Convex.minimize(Convex.sumsquares(Y-X*theta) / (2*n) + lambda[1] * norm(theta[1:5], 2) + lambda[2] * norm(theta[6:10], 2))
#       Convex.solve!(prob)
#
#       @fact beta - vec(theta.value) --> roughly(zeros(Float64, 10), 1e-3)
#
#       active_set = [2]
#       beta = zeros(p)
#       HD.minimize_active_groups!(beta, XX, Xy, groups, active_set, lambda)
#
#       theta = Convex.Variable(5)
#       prob = Convex.minimize(Convex.sumsquares(Y-X[:,6:10]*theta) / (2*n) + lambda[2] * norm(theta, 2))
#       Convex.solve!(prob)
#
#       @fact beta[6:10] - vec(theta.value) --> roughly(zeros(Float64, 5), 1e-3)
#     end
#   end
# end
#
# facts("group lasso") do
#
#   context("two groups") do
#     n = 100
#     p = 10
#     X = randn(n, p)
#     Y = X * ones(p) + 0.1 * randn(n)
#     XX = X' * X / n
#     Xy = X' * Y / n
#
#     groups=Array(Array{Int64, 1}, 2)
#     groups[1] = collect(1:5)
#     groups[2] = collect(6:10)
#
#     lambda_max = maximum(map((x)->norm(Xy[x]), groups)) + 0.1
#     lambda = [lambda_max, lambda_max]
#     beta = zeros(p)
#     HD.group_lasso!(beta, XX, Xy, groups, lambda)
#     @fact beta --> zeros(p)
#
#     lambda = [0.3, lambda_max]
#     beta = zeros(p)
#     HD.group_lasso!(beta, XX, Xy, groups, lambda)
#
#     if cvx && grb
#       theta = Convex.Variable(10)
#       prob = Convex.minimize(Convex.sumsquares(Y-X*theta) / (2*n) + lambda[1] * norm(theta[1:5], 2) + lambda[2] * norm(theta[6:10], 2))
#       Convex.solve!(prob)
#
#       @fact beta - vec(theta.value) --> roughly(zeros(Float64, 10), 1e-3)
#
#       lambda = [lambda_max, 0.6]
#       beta = zeros(p)
#       HD.group_lasso!(beta, XX, Xy, groups, lambda)
#
#       theta = Convex.Variable(10)
#       prob = Convex.minimize(Convex.sumsquares(Y-X*theta) / (2*n) + lambda[1] * norm(theta[1:5], 2) + lambda[2] * norm(theta[6:10], 2))
#       Convex.solve!(prob)
#
#       @fact beta - vec(theta.value) --> roughly(zeros(Float64, 10), 1e-3)
#
#       lambda = [0.3, 0.6]
#       beta = zeros(p)
#       HD.group_lasso!(beta, XX, Xy, groups, lambda)
#
#       # compare to Mosek
#       theta = Convex.Variable(10)
#       prob = Convex.minimize(Convex.sumsquares(Y-X*theta) / (2*n) + lambda[1] * norm(theta[1:5], 2) + lambda[2] * norm(theta[6:10], 2))
#       Convex.solve!(prob)
#
#       @fact beta - vec(theta.value) --> roughly(zeros(Float64, 10), 1e-3)
#     end
#   end
#
#   context("more groups") do
#     n = 400
#     p = 1000
#     X = randn(n, p)
#     Y = X[:,1:50] * ones(50) + 0.1 * randn(n)
#     XX = X' * X / n
#     Xy = X' * Y / n
#
#     if cvx && grb
#       numG = div(p, 5)
#       groups=Array(Array{Int64, 1}, numG)
#       for i=1:numG
#         groups[i] = (i-1)*5+1:i*5
#       end
#       lambda = 0.4 .* ones(numG)
#
#       beta = zeros(p)
#       HD.group_lasso!(beta, XX, Xy, groups, lambda)
#
#       theta = Convex.Variable(p)
#       normT = norm(theta[1:5])
#       for i=2:numG
#         normT = normT + norm(theta[(i-1)*5+1:i*5])
#       end
#       normT = 0.4 * normT
#
#       prob = Convex.minimize(Convex.sumsquares(Y-X*theta) / (2*n) + normT)
#       Convex.solve!(prob)
#       @fact beta - vec(theta.value) --> roughly(zeros(Float64, p), 1e-3)
#
#       beta = zeros(p)
#       HD.group_lasso_raw!(beta, X, Y, groups, lambda)
#       @fact beta - vec(theta.value) --> roughly(zeros(Float64, p), 1e-3)
#     end
#   end
# end


FactCheck.exitstatus()
