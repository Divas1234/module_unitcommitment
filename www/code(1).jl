# Before calling optimize!
set_optimizer_attribute(model, "InfUnbdInfo", 1)
# Or potentially:
# set_optimizer_attribute(model, "Presolve", 0) # This disables presolve entirely

optimize!(model)
# ... rest of the status checking code