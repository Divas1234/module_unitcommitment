using LinearAlgebra, Statistics, Random, GLM

# Function to calculate fitting parameters using linear regression
function calculate_fittingparameters(inertia, damping)
	# Input validation
	if any(x -> x <= 0, inertia) || any(x -> x < 0, damping)
		return zeros(3) # Or throw an error
	end

	Random.seed!(123)
	data_size = length(inertia)
	@assert size(inertia, 1) == size(damping, 1)

	# n_samples = 100

	# regression_params = 2 .* damping .+ 1 .+ 0.1 * randn(n_samples)

	X = hcat(ones(data_size), damping, damping .^ 2)

	data = DataFrame(X, [:intercept, :damping, :damping_squared])
	data.inertia = inertia[:, 1]

	model = lm(@formula(inertia~1 + damping + damping^2), data)

	return coef(model)
end
