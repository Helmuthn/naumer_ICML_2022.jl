using CairoMakie
using naumer_ICML_2022
using LinearAlgebra: tr, svd, dot
using CSV

################################################
########### Plot Parameters ####################
################################################

max_steps = 1000
state = 2*randn(2)
state_cp = copy(state)
crlb = [4.0 0; 0 4.0]


dynamics = [-10.0 0.0; 0.0 -0.1]
τ = 0.01
γ = 0.95
actionSpace = [[sin(θ), cos(θ)] for θ in 0:.05:π]

λ = 0.05
psdSampleCount = [100, 1000]
trajectorySampleCount = 1
timestepSampleCount = 1
σ² = 1
max_iterations = 10000

#################################################
################# Data Generation ###############
#################################################

system = LinearSystem(dynamics)


optimal_sampling_trace_low    = zeros(max_steps)
optimal_sampling_trace_medium = zeros(max_steps)
random_sampling_trace         = zeros(max_steps)

geometric_amplification = [1.0/(1.0 - γ * exp(τ*dynamics[1,1])), 1.0/(1.0 - γ * exp(τ*dynamics[2,2]))]

optimal_sampling_trace_low[1]    = dot([4,4], geometric_amplification)
optimal_sampling_trace_medium[1] = dot([4,4], geometric_amplification)
random_sampling_trace[1]         = dot([4,4], geometric_amplification)

values, psdSamples, stateSamples = ValueFunctionApproximation_NearestNeighbor_precompute(system,
                                                                                        τ,
                                                                                        γ,
                                                                                        actionSpace,
                                                                                        λ,
                                                                                        psdSampleCount[1],
                                                                                        trajectorySampleCount,
                                                                                        timestepSampleCount,
                                                                                        σ²,
                                                                                        max_iterations)



NN_Policy_tuple = (system, σ², τ, values, psdSamples, stateSamples, actionSpace)

for i in 2:max_steps
    global state
    global crlb
    global NN_Policy_tuple
    action, index, state, crlb = NearestNeighbor_OptimalPolicy(  state,
                                                                 crlb,
                                                                 NN_Policy_tuple...)
    ~, S, ~ = svd(crlb)
    optimal_sampling_trace_low[i] = dot(S, geometric_amplification)
end




values, psdSamples, stateSamples = ValueFunctionApproximation_NearestNeighbor_precompute(system,
                                                                                        τ,
                                                                                        γ,
                                                                                        actionSpace,
                                                                                        λ,
                                                                                        psdSampleCount[2],
                                                                                        trajectorySampleCount,
                                                                                        timestepSampleCount,
                                                                                        σ²,
                                                                                        max_iterations)
crlb = [4.0 0; 0 4.0]
state = state_cp

NN_Policy_tuple = (system, σ², τ, values, psdSamples, stateSamples, actionSpace)

for i in 2:max_steps
    global state
    global crlb
    global NN_Policy_tuple
    action, index, state, crlb = NearestNeighbor_OptimalPolicy( state,
                                                                 crlb,
                                                                 NN_Policy_tuple...)
    ~, S, ~ = svd(crlb)
    optimal_sampling_trace_medium[i] = dot(S, geometric_amplification)
end


crlb = [4.0 0; 0 4.0]
state = state_cp
                                             
for i in 2:max_steps
    global state
    global crlb
    action = actionSpace[rand(1:length(actionSpace))]

    jacobian = flowJacobian(state, τ, system)
    crlb = inv(inv(crlb) + (action * action' / σ²))
    crlb = jacobian * crlb * jacobian'

    state = flow(state, τ, system)
    ~, S, ~ = svd(crlb)
    random_sampling_trace[i] = dot(S, geometric_amplification)
end


#################################################
################ Save Data CSV ##################
#################################################

CSV.write("LinearSampling.csv",(random_sampling_trace = random_sampling_trace, 
                                optimal_sampling_trace_low = optimal_sampling_trace_low,
                                optimal_sampling_trace_medium = optimal_sampling_trace_medium,
                                samples = Array(1:max_steps)))

