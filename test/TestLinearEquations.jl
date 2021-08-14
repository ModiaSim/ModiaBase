"""
    module TestLinearEquations - Test LinearEquations(..) in ModiaBase/src/EquationAndStateInfo.jl
"""
module TestLinearEquations

using Test
using ModiaBase
using TimerOutputs

println("... Test TestLinearEquations")

# Solve A*x = b as residual equation
const A = [1.0 2.0 3.0 4.0 5.0;
           0.0 2.0 0.0 0.0 0.0;
           0.0 0.0 3.0 0.0 0.0;
           0.0 0.0 0.0 4.0 0.0;
           0.0 0.0 0.0 0.0 5.0]
const b = [-1.0, -2.0, -3.0, -4.0, -5.0]
const isInitial = true       # the first call must be performed with isInitial=true
const time  = 0.0            # only for warning/error messages
const timer = TimerOutput()  # timer to measure the time to solve the linear equation system
const leq   = ModiaBase.LinearEquations(["x1", "x2"], [5,1], 2, false) # allocate work space once

computeResidual1(x1)    = A*x1-b
computeResidual2(x1,x2) = x1[1] + 2*x1[2] + 3*x1[3] + 4*x2

# Solution
const x1_sol = A\b
const x2_sol = -(x1_sol[1] + 2*x1_sol[2] + 3*x1_sol[3])/4.0

# ------------------------------ old residuals interface -----------------------------------
# Test function for ODE mode
function solveLinearEquation(leq,isInitial,time,timer)
    x1 = zeros(5)
    x2 = 0.0
    leq.mode = -3   
    while ModiaBase.LinearEquationsIteration(leq, isInitial, time, timer)
        x1 = leq.x[1:5]
        x2 = leq.x[6]
        leq.residual_value[1] = computeResidual1(x1)
        leq.residual_value[2] = computeResidual2(x1,x2)
    end
    return (x1,x2)
end

# Test function for DAE mode
function solveLinearEquation(leq,isInitial,solve_leq,isStoreResult,time,timer)
    x1 = zeros(5)
    x2 = 0.0
    leq.mode = -3
    while ModiaBase.LinearEquationsIteration(leq, isInitial, solve_leq, isStoreResult, time, timer)
        x1 = leq.x[1:5]
        x2 = leq.x[6]
        leq.residual_value[1] = computeResidual1(x1)
        leq.residual_value[2] = computeResidual2(x1,x2)
    end
    return (x1,x2)
end


@testset "Test TestLinearEquations1" begin
    # Test ODE mode (x is always explicitly computed by solving the linear equation system)
    (x1,x2) = solveLinearEquation(leq,isInitial,time,timer)

    d1   = x1_sol-x1
    err1 = sqrt(d1'*d1) + abs(x2_sol - x2)
    @test isapprox(err1, 0.0, atol=1e-15)
    
    
    # Test DAE mode
    leq.odeMode = false
   
    # x is computed explicitly at initialization or at an event
    (x1,x2) = solveLinearEquation(leq,false,true,false,time,timer)
    d2   = x1_sol-x1
    err2 = sqrt(d2'*d2) + abs(x2_sol - x2)
    @test isapprox(err2, 0.0, atol=1e-15)

    # x is computed by DAE solver
    leq.x = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]  # Provide x from DAE solver
    (x1,x2) = solveLinearEquation(leq,false,false,false,time,timer)
    residuals = leq.residuals      # Store residuals in DAE solver
    d3 = leq.x - vcat(x1,x2)
    d4 = vcat(A*leq.x[1:5] - b, leq.x[1] + 2*leq.x[2] + 3*leq.x[3] + 4*leq.x[6]) - residuals
    err3 = sqrt(d3'*d3)
    err4 = sqrt(d4'*d4)   
    @test isapprox(err3, 0.0, atol=1e-15)
    @test isapprox(err4, 0.0, atol=1e-15)

    # x is computed by DAE solver at a communication point (leq.residuals is not provided)
    leq.x = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]  # Provide x from DAE solver
    (x1,x2) = solveLinearEquation(leq,false,false,true,time,timer)
    d5 = leq.x - vcat(x1,x2)
    err5 = sqrt(d5'*d5)
    @test isapprox(err5, 0.0, atol=1e-15)
end



# ------------------------------ new residuals interface -----------------------------------
# Test function for ODE mode
function solveLinearEquation2(leq,isInitial,time,timer)
    x1 = zeros(5)
    x2 = 0.0
    leq.mode = -3   
    while ModiaBase.LinearEquationsIteration(leq, isInitial, time, timer, useAppend=true)
        x1 = leq.x[1:5]
        x2 = leq.x[6]
        append!(leq.residuals, computeResidual1(x1))
        append!(leq.residuals, computeResidual2(x1,x2))
    end
    return (x1,x2)
end

# Test function for DAE mode
function solveLinearEquation2(leq,isInitial,solve_leq,isStoreResult,time,timer)
    x1 = zeros(5)
    x2 = 0.0
    leq.mode = -3
    while ModiaBase.LinearEquationsIteration(leq, isInitial, solve_leq, isStoreResult, time, timer, useAppend=true)
        x1 = leq.x[1:5]
        x2 = leq.x[6]
        append!(leq.residuals, computeResidual1(x1))
        append!(leq.residuals, computeResidual2(x1,x2))
    end
    return (x1,x2)
end

@testset "Test TestLinearEquations2" begin
    # Test ODE mode (x is always explicitly computed by solving the linear equation system)
    leq.odeMode = true
    (x1,x2) = solveLinearEquation2(leq,isInitial,time,timer)

    d1   = x1_sol-x1
    err1 = sqrt(d1'*d1) + abs(x2_sol - x2)
    @test isapprox(err1, 0.0, atol=1e-15)
    
    
    # Test DAE mode
    leq.odeMode = false
   
    # x is computed explicitly at initialization or at an event
    (x1,x2) = solveLinearEquation2(leq,false,true,false,time,timer)
    d2   = x1_sol-x1
    err2 = sqrt(d2'*d2) + abs(x2_sol - x2)
    @test isapprox(err2, 0.0, atol=1e-15)

    # x is computed by DAE solver
    leq.x = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]  # Provide x from DAE solver
    (x1,x2) = solveLinearEquation2(leq,false,false,false,time,timer)
    residuals = leq.residuals      # Store residuals in DAE solver
    d3 = leq.x - vcat(x1,x2)
    d4 = vcat(A*leq.x[1:5] - b, leq.x[1] + 2*leq.x[2] + 3*leq.x[3] + 4*leq.x[6]) - residuals
    err3 = sqrt(d3'*d3)
    err4 = sqrt(d4'*d4)   
    @test isapprox(err3, 0.0, atol=1e-15)
    @test isapprox(err4, 0.0, atol=1e-15)

    # x is computed by DAE solver at a communication point (leq.residuals is not provided)
    leq.x = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]  # Provide x from DAE solver
    (x1,x2) = solveLinearEquation2(leq,false,false,true,time,timer)
    d5 = leq.x - vcat(x1,x2)
    err5 = sqrt(d5'*d5)
    @test isapprox(err5, 0.0, atol=1e-15)    
end
    
end