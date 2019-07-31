export dualize

"""
    dualize(model)

Dualize the model
"""
function dualize(model, dual_names::DualNames = DualNames("", ""))
    dualize(model; dual_names = dual_names)    
end

# MOI ModelLike dualization
function dualize(primal_model::MOI.ModelLike; dual_names::DualNames = DualNames("", ""))
    # Crates an empty dual problem
    dual_problem = DualProblem{Float64}()
    return dualize(primal_model, dual_problem, dual_names)
end

function dualize(primal_model::MOI.ModelLike, dual_problem::DualProblem{T}; 
                 dual_names::DualNames = DualNames("", "")) where T
    # Dualize with the optimizer already attached
    return dualize(primal_model, dual_problem, dual_names)
end

function dualize(primal_model::MOI.ModelLike, dual_problem::DualProblem{T}, dual_names::DualNames) where T
    # Throws an error if objective function cannot be dualized
    supported_objective(primal_model) 

    # Query all constraint types of the model
    con_types = MOI.get(primal_model, MOI.ListOfConstraints())
    supported_constraints(con_types) # Throws an error if constraint cannot be dualized
    
    # Set the dual model objective sense
    set_dual_model_sense(dual_problem.dual_model, primal_model)

    # Get Primal Objective Coefficients
    primal_objective = get_primal_objective(primal_model)

    # Add variables to the dual model and their dual cone constraint.
    # Return a dictionary for dual variables with primal constraints
    dual_obj_affine_terms = add_dual_vars_in_dual_cones(dual_problem.dual_model, primal_model, 
                                                        dual_problem.primal_dual_map,
                                                        dual_names, con_types)
    
    # Fill Dual Objective Coefficients Struct
    dual_objective = get_dual_objective(dual_problem.dual_model, 
                                        dual_obj_affine_terms, primal_objective)

    # Add dual objective to the model
    set_dual_objective(dual_problem.dual_model, dual_objective)

    # Add dual equality constraint and get the link dictionary
    add_dual_equality_constraints(dual_problem.dual_model, primal_model,
                                  dual_problem.primal_dual_map, dual_names,
                                  primal_objective, con_types)

    return dual_problem
end

# JuMP model dualization
function dualize(model::JuMP.Model; dual_names::DualNames = DualNames("", ""))
    JuMP_model = JuMP.Model()
    if model.moi_backend.optimizer === nothing
        dual_model = dualize(model.moi_backend)
        MOI.copy_to(JuMP.backend(JuMP_model), dual_model.dual_model)
    else
        # dual_optimizer = deepcopy(model.moi_backend.optimizer)
        # dual_problem = Dualization.DualProblem(dual_optimizer)
        # dualize(model.moi_backend)
        error("Dualize with optimizer attached not implemented")
    end
    return JuMP_model
end