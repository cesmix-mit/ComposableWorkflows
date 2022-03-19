using LinearAlgebra
using StaticArrays
using AtomsBase
using InteratomicPotentials 
using InteratomicBasisPotentials
using Atomistic
using NBodySimulator
using BenchmarkTools
using ThreadsX #julia --threads 4
using Plots

include("load_data.jl")


# System #######################################################################
systems, energies, forces, stresses = load_data("HfO2_relax_1000.xyz")
N = length(systems[1])
initial_system = systems[1]
Δt = 2.5u"ps"


# Thermostat ###################################################################
reference_temp = 800.0u"K"
thermostat_prob = 0.5 # ?
eq_thermostat = NBodySimulator.AndersenThermostat(
                                austrip(reference_temp),
                                thermostat_prob / austrip(Δt))


# Create potential #############################################################
n_body = 4
max_deg = 7
r0 = 1.0
rcutoff = 15.0
wL = 1.0
csp = 1.0
β = [1635.0093430990148, 978.193477904539, 386.1346549917365, 106.63958295148132, 16.51964681655123, 0.5349742898284101, -0.2824707517926808, 8.093887630499285e8, 2.5315516802431303e8, -3.2595087735902168e7, 2.279955127742008e7, -2.392241942310227e7, -4.889744427923971e6, -8.288131477128851e6, -2231.7318272444013, -1963.4271649540326, -256.8591919019885, -2.145012560929677, 17.826279899128767, 3.457352352005932, 11156.883811864207, 8235.323926025249, 4582.8785818469305, 1822.9271686615587, 433.08066447909334, 36.81270409659905, -436.15220006170904, -229.19871151877388, -16.859617106915074, -1.0660061040752737, -384.70257675664504, -326.52223054317557, -158.4610153807277, -36.491277865125845, 60.26187823873083, 25.352823301792306, -10.374327301709153, 4.189692141349909, -173.78769837296096, -51.621287504468256, -13.904156685697407, -2.3478038463692634, 6565.104212960054, 3581.1219399485826, 1311.833550802011, 319.63113664716155, 43.16086362061901, 0.17967172509219917, 4.644498727823202, 313.5776418067523, 131.38565606866044, 25.09111612450762, -3.803519722918627, 6.733627960818492, 0.9559546528419495, 198.0211481821145, 56.213011057000756, -22.27217108622988, -9.359210100842226, 13.800451762680467, 7.09585706494712, 90.12033282113732, 48.84622165295012, 6.870119872436384, -3.0338085059863804, -19.831738681984813, 0.6763547426782996, -4.074525880136091, -30403.475281203067, -70246.80541440337, 6984.521873213264, 12399.339498225547, 3878.0928339436423, 514.245799812929, -8146.997240898392, -5937.342249646655, -922.4933445948099, -59.48311262107248, 247.95180536812705, 71.2704682310052, -26417.170558485777, -18170.94280753791, -2174.542786810897, -135.86287198987787, -434.6448292670565, -130.5270668517596, -1325.6333786495081, -276.2518211666061, 788.969825767466, 694.8590848599845, -138.32087943279348, -13.47072429340444, 1.7652271486461597, -7839.184951545173, -4431.259287885953, -1824.4640293948892, -538.6118597639106, -96.38589411928794, 322.48632436909253, 46.620723564110214, -13.776975633797884, -1194.1360458668023, -489.2064524451345, -90.42462264131802, -11.054043594385822, 46.9481913095099, 136.94926742457017, -49.6241928072683, -1.5685793897347544, -3333.923200505005, -1257.7293880103023, -173.17735401299745, 10.963560892168793, -5.469179319070864, -12.491776101644284, -7.029767636132349, -0.9422192855174674, 79.70799552768428, 12.064704556621614, 9.843117388322657, -6.216932907725849, 83.45668422153128, 12.455990827031908, -4.751666625053637, 17587.34749302717, 23624.93613644486, -1050.098990873782, -2702.5100027850963, -455.50145201608547, 745.0639188409041, 385.4003756075974, 77.09011593743028, 24.906675827978745, 5983.203911378343, 3174.4014001206897, 35.630138058023896, 0.9828308120921164, 212.161910426622, -24.66829655881819, 10.150685431323481, 0.6719350805702469, -17.50282347525073, -18.79427451940884, -71.11830799367631, -31.044959046498793, -13.904366489534663, 2.788254229617344, 18.3172933222983, -6.964851688650561, 6.438165032092542, -7.083246772881083, -0.24546071520857843, 14.049326277426443, 4103.670495409822, 240.62777755964223, 6.310507579347109, 3.644819099310549, 1720.3346020351923, 252.89035255571858, 103.7781490930218, -22.070673217411752, -5.573426565334426, -37.37661310144164, 9.65854096442085, 0.6925511689224255, -69.69504494961669, -36.86656131984636, -6.245529897714304, 7.992918682344236, 31.621688994536772, -7.976754854738684, 1.3262693956998213, -8001.993341291266, -7003.584250446986, -1016.1416406258155, -81.31707150937582, -18.36332487275474, 3.33023185319205, -630.6299384052134, -150.1519082655965, 4.46352579362023, -368.1653875646989, -44.09219744149079, -63.629695151982354, 1.1155097225068498, 626.6657467264477, 394.9867497053556, 13.82288020490767, 2.6036722043489724, 29.09175642736875, 15.987479744705624, -52.01040139765505, -12.338577740039634, 2.520025819231228, -11147.880002492644, 5984.261336069163, -19850.51701986104, -5178.304448172014, -49.2480199271415, -4511.817760818246, -3822.8869949136542, -66.17013025220302, -194.40051110611583, 19083.411769587063, -1974.5221653049064, -1492.8450454373285, -167.15757738653028, -201.48193401394803, -231.3283907069012, -1270.4552092028994, 201.06575825158995, -852.8896196354078, 2219.855197151836, 791.0133178463541, -8.090583882633222e8, -2.5292971302211604e8, 3.271490848534232e7, -2.2750582357495014e7, 2.393714146670177e7, 4.892689097895801e6, 8.288429330933127e6, 2403.572303231123, 1384.1803651379632, 560.9385384133786, 144.67036124621208, 16.984873196872172, -1.0071519217369485, -0.5473281631553755, -716091.6679345666, -855697.091052669, -261150.63793123112, -55166.709216290285, -7548.013518817899, -585.8938770968455, -10143.01504937878, 7957.3146032232, -326.93159139117773, 35.62876182482174, 31.805166683079708, 4.729475200848897, -5485.122268165314, -5301.013961666218, -479.9680423509855, 17.673845849416676, 1014.2520867319826, 153.7119948533103, -12.530403926979105, -0.33712153181089366, -51.01833805257537, -27.72945756034414, 23.977156995054997, 16.531983411138555, -108370.16860190638, -74384.01559576728, -10816.27211909212, -662.1212802590618, -5682.966471703262, 4889.389303481807, -148.19278021034322, -22.800964169730726, -0.7128950239638087, -604.9657877944657, -138.77162712422256, 380.6913686719486, 51.11907690473586, -1.4553539194748315, -0.5595735584731083, -4633.8637854510225, -1060.8204538506845, -2891.0619897064776, 2112.4140725507755, -24.61967957328929, -0.858141633255962, 105.48297197751451, 5.962776135677458, -1391.9057020669868, 587.6024301737231, -2.010345241254935, 11.823858987739925, -527.8472352204209, 79.88222330512434, -101.60604043742678, -3310.125585747816, -2453.790796211945, -168.60627885473295, 98.6661523318159, 22.31267054761986, 4.038977728588582, -481.20416267654485, -449.9864500067929, -80.66688263639485, -7.4193479732561105, -50.559267854985585, -16.223340180845266, -211.53386023941212, -45.852862284292065, 0.4679003753814906, -3.2494046246428687, -40.56085124074307, -11.83759203329924, 3.082057288855118, 2.037382360127455, 348114.14010119904, 513527.22270523704, 98583.28548800705, 8817.371567921398, -298.2195080881176, 66194.312445858, -567.0844143596771, -23.35203740655904, 4.9837118531188205, 2.944488244676365, 10719.043080879279, 8682.844320479568, 193.47272654313122, 1552.1503396406504, -56.34116949647244, 6.7829175050247645, -147.0485941661582, -32.20736643727064, 112492.580478301, 51184.68858381282, 4186.672057895154, 70987.1408369498, -466.73886201163776, -36.960668400692796, 8.380885768300182, 504.95756616586755, 535.0860268439428, -6.367006560908547, 1639.7903113201053, 17569.528320719714, 41.91693653166289, 39.46829078066506, 104.4249281820227, 2954.500989639915, 104.24171988148653, 176.35054911178793, -17878.38958593691, 508.4601344046721, -542.126290437594, -76.22414065606971, 13.498543924229383, 1027.7719739452289, -39.65775885597641, -12.511274754261732, -4.465128930164563, 189.64231932165882, -85.2167092736427, -1.9542400873618702, 11.54680625804059, -3.5118438808808627, -8.851631412753065, -108.36135246904564, -544.5761332499349, 539.8572876308712, -16.67518968684695, 112.62522794263427, -8.347902722136695, -22.196013512543534, 748.5503777937259, -9.92226971988375, 1.6495984287244754, 548.5456219330024, 20.09907744976508, -24.446997821485546, -19.16608026218459, -1071.8085417693594, 28.47927474578387, 5.1843911251882435, 29.32645123189352, 11.817755307327216, -2.7708100721920346, -1.7786106773656416, 39.59366945483737, -55.037854293158304, 2.136994738592094, 1645.4941255440347, 550.4286625616171, 7941.026495291529, -102.31874786918672, -17.038436752450803, -5.494711338039346, 4016.0418349264082, -62.895696033255284, 537.5603838633352, -12278.214553166437, 88.17909545514232, -114.23068089103148, -3.9141244714422707, 302.54813286403885, -57.69691688254715, 100.44125577980381, 0.14205075555797875, 65.56872252102067, -350.3830965069135, 7.2032087311390445, -3.763433976698638, 58.56441877440954, -5928.080760664519, -100.50435377496518, -25.53815368102219, 67.18458165581852, 13.03240914490778, -59.79528010132929, -1802.5065285302805, -25.01338325423953, -263.52742843368696, 825.6156057875996, 475.8764902813456, -159.13950238058277, -49.72882279979387, 9.985452319738313, 394.59230446157113, 136.50397631667755, -7.479154942519661, 12.789127771762395, 73.36707617294618, -37.63452010015358, -8.844359118047207, 4.905093907509523, -4.310329087577522, 21.469250813222555, 66.1545102379813, -2.098724023945686, 16.258154246451735, 6.323991093250096, 3.246428027595515]
rpi_params = RPIParams([:Hf, :O], n_body, max_deg, wL, csp, r0, rcutoff)
potential = RPI(β, rpi_params)

calc_B(systems) = vcat((evaluate_basis.(systems, [rpi_params])'...))

calc_dB(systems) = vcat([vcat(d...) for d in ThreadsX.collect(evaluate_basis_d(s, rpi_params) for s in systems)]...)

function InteratomicPotentials.energy_and_force(s::AbstractSystem, p::RPI)
    B = calc_B([s])
    dB = calc_dB([s])
    e = (B * p.coefficients)[1]
    f = [ SVector(dB[i:i+2,:] * p.coefficients...) for i in 1:3:size(dB,1)]
    return (; e, f)
end


# First stage ##################################################################
eq_steps = 5
eq_simulator = NBSimulator(Δt, eq_steps, thermostat = eq_thermostat)
eq_result = @time simulate(initial_system, eq_simulator, potential)


# Second stage #################################################################
prod_steps = 5
prod_simulator = NBSimulator(Δt, prod_steps, t₀ = get_time(eq_result))
prod_result = @time simulate(get_system(eq_result), prod_simulator, potential)


# Results ######################################################################
temp = plot_temperature(eq_result, 10)
energy = plot_energy(eq_result, 10)

display(plot_temperature!(temp, prod_result, 10))
display(plot_energy!(energy, prod_result, 10))

#rdf = plot_rdf(prod_result, austrip(2.0u"nm"), Int(0.95 * prod_steps))
#display(rdf)
#savefig(rdf, "hf02_ace_nbs_rdf.svg")

animate(prod_result, "hf02_ace_nbs.gif")

