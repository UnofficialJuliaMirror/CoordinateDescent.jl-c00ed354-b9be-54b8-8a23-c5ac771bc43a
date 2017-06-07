######################################################################
#
#   Lasso Solution
#
######################################################################

struct LassoSolution{T}
  x::SparseIterate{T}
  residuals::Vector{T}
  penalty::ProxL1{T}
  σ::Nullable{T}

  LassoSolution{T}(x::SparseIterate{T}, residuals::AbstractVector{T}, penalty::ProxL1{T}, σ::T) where {T} =
    new(x, residuals, penalty, σ)
  LassoSolution{T}(x::SparseIterate{T}, residuals::AbstractVector{T}, penalty::ProxL1{T}) where {T} =
    new(x, residuals, penalty, Nullable{T}( ))
end


######################################################################
#
#   Lasso Interface
#
######################################################################

lasso{T<:AbstractFloat}(
  X::StridedMatrix{T},
  y::StridedVector{T},
  λ::T,
  options::CDOptions=CDOptions()) =
    coordinateDescent!(SparseIterate(size(X, 2)), CDLeastSquaresLoss(y,X), ProxL1(λ), options)

lasso{T<:AbstractFloat}(
  X::StridedMatrix{T},
  y::StridedVector{T},
  λ::T,
  ω::Array{T},
  options::CDOptions=CDOptions()) =
    coordinateDescent!(SparseIterate(size(X, 2)), CDLeastSquaresLoss(y,X), ProxL1(λ, ω), options)


######################################################################
#
#   Sqrt-Lasso Interface
#
######################################################################


sqrtLasso{T<:AbstractFloat}(
  X::StridedMatrix{T},
  y::StridedVector{T},
  λ::T,
  options::CDOptions=CDOptions()) =
    coordinateDescent!(SparseIterate(size(X, 2)), CDSqrtLassoLoss(y,X), ProxL1(λ), options)

sqrtLasso{T<:AbstractFloat}(
  X::StridedMatrix{T},
  y::StridedVector{T},
  λ::T,
  ω::Array{T},
  options::CDOptions=CDOptions()) =
    coordinateDescent!(SparseIterate(size(X, 2)), CDSqrtLassoLoss(y,X), ProxL1(λ, ω), options)


######################################################################
#
#   Scaled Lasso Interface
#
######################################################################

function scaledLasso!{T<:AbstractFloat}(
  β::SparseIterate{T},
  X::AbstractMatrix{T},
  y::AbstractVector{T},
  λ::T,
  ω::AbstractVector{T},
  options::IterLassoOptions=IterLassoOptions()
  )

  n, p = size(X)
  f = CDLeastSquaresLoss(y,X)

  # initializa σ
  if options.initProcedure == :Screening
    σ = _findInitSigma!(X, y, options.sinit, f.r)
  elseif options.initProcedure == :InitStd
    σ = options.σinit
  elseif options.initProcedure == :WarmStart
    initialize!(f, x)
    σ = std(f.r)
  else
    throw(ArgumentError("Incorrect initialization Symbol"))
  end

  for iter=1:options.maxIter
    g = ProxL1(λ * σ, ω)
    coordinateDescent!(β, f, g, options.optionsCD)
    σnew = sqrt( sum(abs2, f.r) / n )

    if abs(σnew - σ) / σ < options.optTol
      break
    end
    σ = σnew
  end
  β, σ
end


######################################################################
#
#   Lasso Path Interface
#
######################################################################


function feasibleLasso!{T<:AbstractFloat}(
  β::SparseIterate{T},
  X::AbstractMatrix{T},
  y::AbstractVector{T},
  λ0::T,
  options::IterLassoOptions=IterLassoOptions()
  )

  n, p = size(X)
  f = CDLeastSquaresLoss(y,X)
  Γ = Array{T}(p)              # stores loadings
  Γold = Array{T}(p)

  # initializa residuals
  if options.initProcedure == :Screening
    _findInitResiduals!(X, y, options.sinit, f.r)
  elseif options.initProcedure == :InitStd
    σ = options.σinit
    _stdX!(Γ, X)
    coordinateDescent!(β, f, ProxL1(λ0*σ, Γ), options.optionsCD)
  elseif options.initProcedure == :WarmStart
    initialize!(f, x)
  else
    throw(ArgumentError("Incorrect initialization Symbol"))
  end
  _getLoadings!(Γ, X, f.r)

  g = ProxL1(λ0, Γ)
  for iter=1:options.maxIter
    copy!(Γold, Γ)

    coordinateDescent!(β, f, g, options.optionsCD)
    _getLoadings!(Γ, X, f.r)

    if maximum(abs.(Γold  - Γ)) / maximum(Γ) < options.optTol
      break
    end
  end
  β
end

######################################################################
#
#   Lasso Path Interface
#
######################################################################


struct LassoPath{T<:AbstractFloat}
  λpath::Vector{T}
  βpath::Vector{SparseIterate{T,1}}
end

function refitLassoPath{T<:AbstractFloat}(
  path::LassoPath{T},
  X::StridedMatrix{T},
  Y::StridedVector{T})

  λpath = path.λpath
  βpath = path.βpath

  out = Dict{Vector{Int64},Vector{Float64}}()
  for i=1:length(λpath)
    S = find(βpath[i])
    if haskey(out, S)
      continue
    end
    out[S] = X[:, S] \ Y
  end
  out
end


# λArr is in decreasing order
function LassoPath(
  X::StridedMatrix{T},
  Y::StridedVector{T},
  λpath::Vector{T},
  options=CDOptions();
  max_hat_s=Inf, standardizeX::Bool=true) where {T<:AbstractFloat}

  n, p = size(X)
  stdX = Array{T}(p)
  if standardizeX
    _stdX!(stdX, X)
  else
    fill!(stdX, one(T))
  end

  β = SparseIterate(T, p)
  f = CDLeastSquaresLoss(Y, X)

  numλ  = length(λpath)
  βpath = Vector{SparseIterate{T}}(numλ)

  for indλ=1:numλ
    coordinateDescent!(β, f, ProxL1(λpath[indλ], stdX), options)
    βpath[indλ] = copy(β)
    if nnz(β) > max_hat_s
      resize!(λpath, indλ)
      break
    end
  end

  LassoPath{T}(copy(λpath), βpath)
end
