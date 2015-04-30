using LightGraphs, Distributions, GraphLayout, Compose

function linear_to_grid(k, N)
	i = mod(k-1, 2N+1) - N
	j = div(k-1, 2N+1) - N
	return (i,j)
end

grid_to_linear(i, j, N) = (j+N) * (2N+1) + (i+N) + 1


# Creates a 2D lattice on [-N,N] × [-N,N]. Adds N^α random shortcuts, where the
# probability that the edge has a particular length is proportional to the distance
# to the -β-th power.
function graph_generator(N, α, β)

	g2l(i, j) = grid_to_linear(i, j, N)

	# step 1: create the underlying lattice
	gr = Graph((2N+1)^2)
	for i in -N:(N-1), j in -N:(N-1)
		add_edge!(gr, g2l(i,j), g2l(i+1,j))
		add_edge!(gr, g2l(i,j), g2l(i,j+1))
	end
	for i in -N:(N-1)
		add_edge!(gr, g2l(N,i), g2l(N,i+1))
		add_edge!(gr, g2l(i,N), g2l(i+1,N))
	end

	# step 2: add shortcuts
	# for each edge to add (of which there are N^\alpha)
	# we pick one endpoint uniformly at random
	# and the other (by acceptance-rejection) with probability
	# proportional to (link length)^-\beta
	du = DiscreteUniform(-N, N)
	for _ in 1:floor(N^α)
		# first endpoint
		i, j = rand(du), rand(du)
		# find normalizing constant
		c = 0.0
		for ei in -N:N, ej in -N:N
			if (i,j) != (ei,ej) #i != ei || j != ej
				c += 1 / (abs(i-ei) + abs(j-ej))^β
			end
		end
		# accpetance rejection for other endpoint, break on success
		while true
			k, l = rand(du), rand(du)
			if (k,l) == (i,j) || has_edge(gr, g2l(i,j), g2l(k,l))
				continue
			end
			dβ = 1 / (abs(i-k) + abs(j-l))^β
			if rand() < dβ / c
				add_edge!(gr, g2l(i,j), g2l(k,l))
				break
			end
		end
	end

	return gr
end

function plot_graph(gr::Graph)
	am = full(adjacency_matrix(gr))
	loc_x, loc_y = layout_spring_adj(am)
	draw_layout_adj(am, loc_x, loc_y, filename="lattice-with-jumps.svg")
end

function plot_graph(gr::Graph, weights)
	am = full(adjacency_matrix(gr))
	loc_x, loc_y = layout_spring_adj(am)
	draw_layout_adj(am, loc_x, loc_y, filename="lattice-with-jumps.svg", labels=weights)
end

# function distances_to_origin(gr)
# 	V = length(vertices(gr))
# 	N = convert(Int, (sqrt(V) - 1) / 2)
# 	dij = dijkstra_shortest_paths(gr, grid_to_linear(0,0,N))
# 	return dij.dists
# end

function assign_population(gr, M, γ, δ)
	V = length(vertices(gr))
	N = convert(Int, (sqrt(V) - 1) / 2)
	dij = dijkstra_shortest_paths(gr, grid_to_linear(0,0,N))
	dist = dij.dists
	q = 1 ./ dist^γ
	# Manually say that no-one lives in the center
	q[grid_to_linear(0,0,N)] = 0.0
	qtot = sum(q)
	pop = zeros(Int, V)

	du = DiscreteUniform(1,V)
	for _ in 1:M
		i = 0
		while true
			i = rand(du)
			r = rand()
			if r < q[i] / qtot
				break
			end
		end
		@show linear_to_grid(i,N)
		pop[i] += 1
		qtot -= q[i]
		q[i] = 1 / (dist[i]^γ * (pop[i]+1)^δ)
		qtot += q[i]
	end
	return pop
end
