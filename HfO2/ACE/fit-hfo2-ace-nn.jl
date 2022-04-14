using AtomsBase
using InteratomicPotentials 
using InteratomicBasisPotentials
using LinearAlgebra 
using Random
using StaticArrays
using Statistics 
using StatsBase
using UnitfulAtomic
using Unitful 
using Flux
using Flux.Data: DataLoader
using BSON: @save
using CUDA
using BenchmarkTools
using Plots

include("load_data.jl")


# Input: experiment_path, dataset_path, dataset_file, n_body, max_deg, r0, rcutoff, wL, csp
if size(ARGS, 1) == 0
    input = ["fit-ahfo2-ace-nn/", "data/", "a-Hfo2-300K-NVT.extxyz",
             "1000", "2", "3", "1", "5", "1", "1"]
else
    input = ARGS
end

experiment_path = input[1]
run(`mkdir -p $experiment_path`)

# Load training and test datasets ##############################################
dataset_path = input[2]
dataset_filename = input[3]
systems, energies, forces, stresses = load_data(dataset_path*dataset_filename)

# Split into training, testing
n_systems = parse(Int64, input[4]) # length(systems)
n_train = floor(Int, n_systems * 0.8)
n_test  = n_systems - n_train
rand_list = randperm(n_systems)
train_index, test_index = rand_list[1:n_train], rand_list[n_train+1:n_systems]
train_systems, train_energies, train_forces, train_stress =
                             systems[train_index], energies[train_index],
                             forces[train_index], stresses[train_index]
test_systems, test_energies, test_forces, test_stress =
                             systems[test_index], energies[test_index],
                             forces[test_index], stresses[test_index]


# Create RPI Basis #############################################################
n_body = parse(Int64, input[5])
max_deg = parse(Int64, input[6])
r0 = parse(Float64, input[7])
rcutoff = parse(Float64, input[8])
wL = parse(Float64, input[9])
csp = parse(Float64, input[10])
rpi_params = RPIParams([:Hf, :O], n_body, max_deg, wL, csp, r0, rcutoff)


# Calculate descriptors ########################################################
calc_B(sys) = evaluate_basis.(sys, [rpi_params])
calc_dB(sys) = [ dBs_comp for dBs_sys in evaluate_basis_d.(sys, [rpi_params])
                          for dBs_atom in dBs_sys
                          for dBs_comp in eachrow(dBs_atom)]
B_time = @time @elapsed B_train = calc_B(train_systems)
dB_time = @time @elapsed dB_train = calc_dB(train_systems)
write(experiment_path*"B_train.dat", "$(B_train)")
write(experiment_path*"dB_train.dat", "$(dB_train)")


# Calculate train energies and forces ##########################################
e_train = train_energies
f_train = vcat([vcat(vcat(f...)...) for f in train_forces]...)
write(experiment_path*"e_train.dat", "$(e_train)")
write(experiment_path*"f_train.dat", "$(f_train)")


# Calculate neural network parameters ##########################################
e_ref = maximum(e_train); f_ref = maximum(abs.(f_train))
train_loader = DataLoader(([B_train; dB_train], 
                           [e_train / e_ref; f_train / f_ref]),
                            batchsize=64, shuffle=true)
n_desc = size(B_train[1], 1)
model = Chain(Dense(n_desc,32,Flux.tanh),
              Dense(32,24,Flux.tanh),
              Dense(24,1))
nn(d) = sum(model(d))
ps = Flux.params(model)
n_params = sum(length, Flux.params(model))
loss(b_pred, b) = sum(abs.(b_pred .- b)) / length(b)
global_loss(loader) =
    sum([loss(nn.(d), b) for (d, b) in loader]) / length(loader)
opt = ADAM(0.0001) # ADAM(0.002, (0.9, 0.999)) 
epochs = 4
for epoch in 1:epochs
    # Training of one epoch
    time = Base.@elapsed for (d, b) in train_loader
        gs = gradient(() -> loss(nn.(d), b), ps)
        Flux.Optimise.update!(opt, ps, gs)
    end
    # Report traning loss
    println("Epoch: $(epoch), loss: $(global_loss(train_loader)), time: $(time)")
end

write(experiment_path*"params.dat", "$(ps)")

# Compute errors ##############################################################
function compute_errors(x_pred, x)
    x_rmse = sqrt(sum((x_pred .- x).^2) / length(x))
    x_mae = sum(abs.(x_pred .- x)) / length(x)
    x_mre = mean(abs.((x_pred .- x) ./ x))
    x_maxre = maximum(abs.((x_pred .- x) ./ x))
    return x_rmse, x_mae, x_mre, x_maxre
end

# Compute training errors
e_train_pred = nn.(B_train) * e_ref
f_train_pred = nn.(dB_train) * f_ref
e_train_rmse, e_train_mae, e_train_mre, e_train_maxre = compute_errors(e_train_pred, e_train)
f_train_rmse, f_train_mae, f_train_mre, f_train_maxre = compute_errors(f_train_pred, f_train)

# Compute test errors
B_test = calc_B(test_systems)
dB_test = calc_dB(test_systems)
e_test = test_energies
f_test = vcat([vcat(vcat(f...)...) for f in test_forces]...)
e_test_pred = nn.(B_test) * e_ref
f_test_pred = nn.(dB_test) * f_ref
e_test_rmse, e_test_mae, e_test_mre, e_test_maxre = compute_errors(e_test_pred, e_test)
f_test_rmse, f_test_mae, f_test_mre, f_test_maxre = compute_errors(f_test_pred, f_test)


## Save results #################################################################
write(experiment_path*"results.csv", "dataset,\
                      n_systems,n_params,n_body,max_deg,r0,rcutoff,wL,csp,\
                      e_train_rmse,e_train_mae,e_train_mre,e_train_maxre,\
                      f_train_rmse,f_train_mae,f_train_mre,f_train_maxre,\
                      e_test_rmse,e_test_mae,e_test_mre,e_test_maxre,\
                      f_test_rmse,f_test_mae,f_test_mre,f_test_maxre,\
                      B_time,dB_time
                      $(dataset_filename), \
                      $(n_systems),$(n_params),$(n_body),$(max_deg),$(r0),$(rcutoff),$(wL),$(csp),\
                      $(e_train_rmse),$(e_train_mae),$(e_train_mre),$(e_train_maxre),\
                      $(f_train_rmse),$(f_train_mae),$(f_train_mre),$(f_train_maxre),\
                      $(e_test_rmse),$(e_test_mae),$(e_test_mre),$(e_test_maxre),\
                      $(f_test_rmse),$(f_test_mae),$(f_test_mre),$(f_test_maxre),\
                      $(B_time),$(dB_time)")
write(experiment_path*"results-short.csv", "dataset,\
                      n_systems,n_params,n_body,max_deg,r0,rcutoff,wL,csp,\
                      e_test_rmse,e_test_mae,\
                      f_test_rmse,f_test_mae,\
                      B_time,dB_time
                      $(dataset_filename), \
                      $(n_systems),$(n_params),$(n_body),$(max_deg),$(r0),$(rcutoff),$(wL),$(csp),\
                      $(e_test_rmse),$(e_test_mae),\
                      $(f_test_rmse),$(f_test_mae),\
                      $(B_time),$(dB_time)")
e = plot( e_test, e_test_pred, seriestype = :scatter, markerstrokewidth=0,
          label="", xlabel = "E DFT | eV/atom", ylabel = "E predicted | eV/atom")
savefig(e, experiment_path*"e.png")
f = plot( f_test, f_test_pred, seriestype = :scatter, markerstrokewidth=0,
          label="", xlabel = "F DFT | eV/Å", ylabel = "F predicted | eV/Å")
savefig(f, experiment_path*"f.png")
