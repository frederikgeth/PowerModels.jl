@testset "test multinetwork multiphase" begin

    @testset "idempotent unit transformation" begin
        @testset "5-bus replicate case" begin
            mn_mp_data = build_mn_mp_data("../test/data/matpower/case5_dc.m")

            PowerModels.make_mixed_units(mn_mp_data)
            PowerModels.make_per_unit(mn_mp_data)

            @test InfrastructureModels.compare_dict(mn_mp_data, build_mn_mp_data("../test/data/matpower/case5_dc.m"))
        end
        @testset "14+24 hybrid case" begin
            mn_mp_data = build_mn_mp_data("../test/data/matpower/case14.m", "../test/data/matpower/case24.m")

            PowerModels.make_mixed_units(mn_mp_data)
            PowerModels.make_per_unit(mn_mp_data)

            @test InfrastructureModels.compare_dict(mn_mp_data, build_mn_mp_data("../test/data/matpower/case14.m", "../test/data/matpower/case24.m"))
        end
    end


    @testset "topology processing" begin
        @testset "7-bus replicate status case" begin
            mn_mp_data = build_mn_mp_data("../test/data/matpower/case7_tplgy.m")
            PowerModels.propagate_topology_status(mn_mp_data)

            active_buses = Set(["2", "4", "5", "7"])
            active_branches = Set(["8"])
            active_dclines = Set(["3"])

            for (i,nw_data) in mn_mp_data["nw"]
                for (i,bus) in nw_data["bus"]
                    if i in active_buses
                        @test bus["bus_type"] != 4
                    else
                        @test bus["bus_type"] == 4
                    end
                end

                for (i,branch) in nw_data["branch"]
                    if i in active_branches
                        @test branch["br_status"] == 1
                    else
                        @test branch["br_status"] == 0
                    end
                end

                for (i,dcline) in nw_data["dcline"]
                    if i in active_dclines
                        @test dcline["br_status"] == 1
                    else
                        @test dcline["br_status"] == 0
                    end
                end
            end
        end
        @testset "7-bus replicate filer case" begin
            mn_mp_data = build_mn_mp_data("../test/data/matpower/case7_tplgy.m")
            PowerModels.propagate_topology_status(mn_mp_data)
            PowerModels.select_largest_component(mn_mp_data)

            active_buses = Set(["4", "5", "7"])
            active_branches = Set(["8"])
            active_dclines = Set(["3"])

            for (i,nw_data) in mn_mp_data["nw"]
                for (i,bus) in nw_data["bus"]
                    if i in active_buses
                        @test bus["bus_type"] != 4
                    else
                        @test bus["bus_type"] == 4
                    end
                end

                for (i,branch) in nw_data["branch"]
                    if i in active_branches
                        @test branch["br_status"] == 1
                    else
                        @test branch["br_status"] == 0
                    end
                end

                for (i,dcline) in nw_data["dcline"]
                    if i in active_dclines
                        @test dcline["br_status"] == 1
                    else
                        @test dcline["br_status"] == 0
                    end
                end
            end
        end
        @testset "7+14 hybrid filer case" begin
            mn_mp_data = build_mn_mp_data("../test/data/matpower/case7_tplgy.m", "../test/data/matpower/case14.m")
            PowerModels.propagate_topology_status(mn_mp_data)
            PowerModels.select_largest_component(mn_mp_data)

            case7_data = mn_mp_data["nw"]["1"]
            case14_data = mn_mp_data["nw"]["2"]

            case7_active_buses = filter((i, bus) -> bus["bus_type"] != 4, case7_data["bus"])
            case14_active_buses = filter((i, bus) -> bus["bus_type"] != 4, case14_data["bus"])

            @test length(case7_active_buses) == 3
            @test length(case14_active_buses) == 14
        end
    end


    @testset "test multi-network multi-phase ac opf" begin

        @testset "3 period 5-bus 3-phase asymmetric case" begin
            mn_mp_data = build_mn_mp_data("../test/data/matpower/case5_asym.m", replicates=3, phases=3)

            @test length(mn_mp_data["nw"]) == 3

            result = PowerModels.run_mn_mp_opf(mn_mp_data, ACPPowerModel, ipopt_solver)

            @test result["status"] == :LocalOptimal
            @test isapprox(result["objective"], 157967.0; atol = 1e0)

            @test length(result["solution"]["nw"]) == 3

            for ph in 1:mn_mp_data["phases"]
                @test isapprox(
                    result["solution"]["nw"]["1"]["gen"]["2"]["pg"][ph],
                    result["solution"]["nw"]["2"]["gen"]["2"]["pg"][ph]; 
                    atol = 1e-3
                )
                @test isapprox(
                    result["solution"]["nw"]["1"]["gen"]["4"]["pg"][ph],
                    result["solution"]["nw"]["2"]["gen"]["4"]["pg"][ph]; 
                    atol = 1e-3
                )
                @test isapprox(
                    result["solution"]["nw"]["2"]["gen"]["2"]["pg"][ph],
                    result["solution"]["nw"]["3"]["gen"]["2"]["pg"][ph]; 
                    atol = 1e-3
                )
                @test isapprox(
                    result["solution"]["nw"]["2"]["gen"]["4"]["pg"][ph],
                    result["solution"]["nw"]["3"]["gen"]["4"]["pg"][ph]; 
                    atol = 1e-3
                )
            end

            for (nw, network) in result["solution"]["nw"]
                @test network["phases"] == 3
                for ph in 1:network["phases"]
                    @test isapprox(network["gen"]["1"]["pg"][ph],  0.4; atol = 1e-3)
                    @test isapprox(network["bus"]["2"]["va"][ph], -0.012822; atol = 1e-3)
                end
            end

        end

        @testset "14+24 3-phase hybrid case" begin
            mn_mp_data = build_mn_mp_data("../test/data/matpower/case14.m", "../test/data/matpower/case24.m", phases_1=3, phases_2=3)

            @test length(mn_mp_data["nw"]) == 2

            result = PowerModels.run_mn_mp_opf(mn_mp_data, ACPPowerModel, ipopt_solver)

            @test result["status"] == :LocalOptimal
            @test isapprox(result["objective"], 2.67529e5; atol = 1e0)

            @test length(result["solution"]["nw"]) == 2

            for (nw, network) in result["solution"]["nw"]
                @test network["phases"] == 3
            end
        end

        @testset "14+24 mixed-phase hybrid case" begin
            mn_mp_data = build_mn_mp_data("../test/data/matpower/case14.m", "../test/data/matpower/case24.m", phases_1=4, phases_2=0)

            @test length(mn_mp_data["nw"]) == 2

            result = PowerModels.run_mn_mp_opf(mn_mp_data, ACPPowerModel, ipopt_solver)

            @test result["status"] == :LocalOptimal
            @test isapprox(result["objective"], 120623.0; atol = 1e1)

            @test length(result["solution"]["nw"]) == 2

            nw_sol_1 = result["solution"]["nw"]["1"]
            nw_sol_2 = result["solution"]["nw"]["2"]

            @test nw_sol_1["phases"] == 4
            @test !haskey(nw_sol_2, "phases")

        end
    end



    @testset "test multi-network multi-phase opf variants" begin
        mn_mp_data = build_mn_mp_data("../test/data/matpower/case5_dc.m", "../test/data/matpower/case14.m", phases_1=4, phases_2=0)

        @testset "ac 5/14-bus case" begin
            result = PowerModels.run_mn_mp_opf(mn_mp_data, ACPPowerModel, ipopt_solver)

            @test result["status"] == :LocalOptimal
            @test isapprox(result["objective"], 80706.2; atol = 1e-1)
        end

        @testset "dc 5/14-bus case" begin
            result = PowerModels.run_mn_mp_opf(mn_mp_data, DCPPowerModel, ipopt_solver)

            @test result["status"] == :LocalOptimal
            @test isapprox(result["objective"], 80006.2; atol = 1e-1)
        end

        @testset "soc 5/14-bus case" begin
            result = PowerModels.run_mn_mp_opf(mn_mp_data, SOCWRPowerModel, ipopt_solver)

            @test result["status"] == :LocalOptimal
            @test isapprox(result["objective"], 69827.3; atol = 1e-1)
        end

    end


    @testset "test solution feedback" begin
        mn_mp_data = build_mn_mp_data("../test/data/matpower/case5_dc.m", "../test/data/matpower/case5_asym.m", phases_1=4, phases_2=0)

        result = PowerModels.run_mn_mp_opf(mn_mp_data, ACPPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 90176.6; atol = 1e0)

        PowerModels.update_data(mn_mp_data, result["solution"])

        @test !InfrastructureModels.compare_dict(mn_mp_data, build_mn_mp_data("../test/data/matpower/case5_dc.m", "../test/data/matpower/case5_asym.m", phases_1=4, phases_2=0))
    end

end