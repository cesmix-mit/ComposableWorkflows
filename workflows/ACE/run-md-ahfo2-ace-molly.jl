using AtomsBase
using InteratomicPotentials 
using InteratomicBasisPotentials
using PotentialLearning
using Atomistic
using Molly
using LinearAlgebra
using StaticArrays
using BenchmarkTools
using Plots


path = "md-ahfo2-ace-molly/"
run(`mkdir -p $path`)


# Load system ##################################################################
systems, energies, forces, stresses = load_extxyz("../data/a-Hfo2-300K-NVT-6000.extxyz", 
                                                   max_entries = 1)
init_sys = first(systems)
N = length(init_sys)
Δt = 1.0u"fs"


# Define thermostat ############################################################
reference_temp = 300.0u"K"
ν = 10 / Δt # stochastic collision frequency
thermostat = Molly.AndersenThermostat(austrip(reference_temp), austrip(ν))
#τNH = 20000Δt
#thermostat = NBodySimulator.NoseHooverThermostat(austrip(reference_temp), austrip(τNH))


# Create potential #############################################################
n_body = 5; max_deg = 4; r0 = 1; rcutoff = 5; wL = 1; csp = 1
β = [289.03539163140346, 243.48118376283978, 108.90687137892282, 21.886754309434895,
     1986.9255669490472, -1105.3139909481295, 150.91277245090194, -316.3360361622922,
     4442.5602659711985, 3127.5733555547745, 437.3811224294227, 7354.857545106271,
     -1464.4044586728367, -400.406760388661, -84.2196862976707, 399.1879766411595,
     81.54274942573873, 2318.48873909869, 100.52900068199892, 161.05798499141454,
     4716.07954635959, 2139.0712576172386, 444.8631203936532, -73.01393900111813,
     -33.719482305330025, 15196.177556047525, 4330.6986031837805, -14350.723394798757,
     -942.91049415333, -4583.404161805665, -31040.467251023252, 1848.962668477575,
     -1476.5638963758054, -2199.0531879446817, -2427.318853536076, -22310.44359518734,
      97521.87531005105, -155232.62453097245, 123615.03808053708, -15988.42430713422,
     -1573.1497954435372, 1248.8288515459476, -169.32732764766297, 308.08244059988715,
     -27531.550545519836, -10345.657693071933, -2603.0198871567645, -382.82365287792487,
     -3406.476973797932, -1117.788126007955, -49.91050089521923, 116422.08516609689,
     8809.66118170756, -3041.3441662083865, -125.40545667372514, 129.35650924627458,
     -0.20264775755634293, 4889.218423504731, 29.035329621461603, 373.0241896645763,
     -327577.44338022626, -103215.75445974572, -3336.7505626500824, -851.7373102727595,
     345.1093509847407, 6155.590046247002, 1749.6325654045584, -362055.2899993088,
    -62707.27537257265, -4431.574887872929, 747733.750387841, 322994.9457702594,
    -47556.4588236927, 1.27954843002649e6, 468128.6553864279, -2109.27294651018,
    3323.0139252376966, 578750.1678740619, -168722.5431704862, 478445.57935367734]
ace_params = ACEParams([:Hf, :O], n_body, max_deg, wL, csp, r0, rcutoff)
ace = ACE(β, ace_params)

# TODO: this function should be added to InteratomicBasisPotentials.jl?
function InteratomicPotentials.energy_and_force(s::AbstractSystem, p::ACE)
    B = evaluate_basis(s, p.basis_params)
    dB = evaluate_basis_d(s, p.basis_params)
    e = austrip.(B' * p.coefficients * 1u"eV")
    f = [SVector(austrip.(d' * p.coefficients .* 1u"eV/Å")...) for d in dB]
    return (; e, f)
end


# Run MD simulation ############################################################
steps = 500 # 100_000
sim = MollySimulator(Δt, steps, coupling = thermostat)
md_res = @time simulate(init_sys, sim, ace)


# Post-process and save results ################################################
savefig(Atomistic.plot_temperature(md_res, 10), path*"temp.svg")
savefig(Atomistic.plot_energy(md_res, 10), path*"energy.svg")
savefig(Atomistic.plot_rdf(md_res, 1.0, Int(0.95 * steps)), path*"rdf.svg")
Atomistic.animate(md_res, path*"anim.gif")

