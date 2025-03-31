// Proyecto 1, Temporada 3

// Esteban Gomez Valerio
// Rafael Takata Garcia
// Roi Jared Flores Garza Stone

// Importar los nodos 
LOAD CSV WITH HEADERS FROM 'file:///got-s3-nodes.csv' AS row
CREATE (n:Personaje)
SET n = row

// Incluir indices para los nodos
CREATE INDEX index_p FOR (n:Personaje) ON (n.Id)

// Relaciones 
LOAD CSV FROM 'file:///got-s3-edges.csv' AS row
MATCH (n:Personaje), (m:Personaje)
WHERE n.Id=row[0] AND m.Id=row[1]
MERGE (n)-[r:CONNECTED_TO]->(m)
SET r.weight = row[2]

////////// EDA

// 1. ¿Cuantos nodos totales hay?
MATCH (n:Personaje)
RETURN COUNT(n) AS Total_Nodos

// 2. ¿Cuantas relaciones hay?
MATCH (n)-[r]->(n2)
RETURN COUNT(DISTINCT(r))

// 3. Esquema general del grafo
CALL db.schema.visualization

// 4. Tipos de nodos y sus propiedades
CALL db.schema.nodeTypeProperties

// 5. Tipos de relaciones y sus propiedades
CALL db.schema.relTypeProperties

// 6. Calcular el diametro del grafo
// Crear un subgrafo
CALL gds.graph.project("diam",
                        "Personaje", 
                        "CONNECTED_TO")

// Calcular el diametro
    CALL gds.alpha.allShortestPaths.stream("diam")
    YIELD sourceNodeId, targetNodeId, distance
    RETURN max(distance) AS graph_diameter

// Calcular el diametro de otra manera
MATCH (a), (b)
WHERE id(a) <> id(b)
WITH a, b, shortestPath((a)-[*]-(b)) AS path
RETURN length(path) AS diametro
ORDER BY diametro DESC
LIMIT 1

// 7. Densidad del grafo
MATCH (n:Personaje) 
WITH count(n) AS N
MATCH ()-[r]->() 
WITH N, count(r) AS E
RETURN toFloat(E) / (N * (N - 1)) AS density

// 8. Relaciones bidireccionales, Fueron 0
MATCH (a)-[r1]->(b)
MATCH (b)-[r2]->(a) 
RETURN COUNT(*) AS cantidad_bidireccional

// 9. ¿Cuantas relaciones hay por cada peso distinto?
MATCH(n:Personaje)-[r:CONNECTED_TO]->(n2:Personaje)
SET r.weight = toInteger(r.weight)
RETURN DISTINCT(r.weight) AS Peso, COUNT(r) AS Cantidad_Relaciones
ORDER BY Peso 

// 10. ¿Que relacion tiene mayor peso y quienes participan en ella?
MATCH(n:Personaje)-[r:CONNECTED_TO]->(n2:Personaje)
RETURN n.Label AS Name, n2.Label AS Target, r.weight AS Peso
ORDER BY Peso DESC
LIMIT 1

// 11. ¿Cuántos nodos sin relaciones existen? 
MATCH (n:Personaje)
WHERE NOT (n)-->() 
RETURN COUNT(n) AS Nodos_sin_relaciones

// 12. ¿Cuántas relaciones entre uno y dos saltos tiene el personaje que aparece en la mayor relación con weight (Jon)? MATCH (p:Personaje{Label:'Jon'})-[*1..2]-(m)
MATCH (p:Personaje{Label:'Jon'})-[*1..2]-(m)
RETURN COUNT (DISTINCT m) AS NodosAlcanzables;

// 13. ¿Cuántos nodos tienen relaciones entrantes y salientes? 
MATCH (n:Personaje)
WHERE (n)-->() AND ()-->(n)
RETURN COUNT(n)

// 14. 
// 15. 

//Preguntas de centralidad

// 1. ¿Cuál personaje es el que más conexiones totales tiene? 
call gds.graph.project("degree",
                        "Personaje",
                        {CONNECTED_TO: {orientation: "UNDIRECTED"}})

CALL gds.degree.write('degree', { writeProperty: 'degree' })
YIELD centralityDistribution, nodePropertiesWritten
RETURN centralityDistribution.min AS minimumScore, centralityDistribution.mean AS meanScore, nodePropertiesWritten

MATCH (p:Personaje)
RETURN p.Label as name, p.degree as degree
order by degree desc
limit 1

// 2. ¿Existe algún personaje que esté desconectado de los demás? 

MATCH (p:Personaje)
where p.degree = 0
RETURN p.Label as name

// 3. ¿Cuál es el personaje que más poder tiene? 

CALL gds.graph.project("pageRank",
                        "Personaje",
                        {CONNECTED_TO: {orientation: "UNDIRECTED"}})

CALL gds.pageRank.write('pageRank', {
  maxIterations: 20,
  dampingFactor: 0.85,
  writeProperty: 'pagerank'
})
YIELD nodePropertiesWritten, ranIterations

MATCH (n:Personaje)
RETURN n.Label as name, n.pagerank as pagerank
ORDER BY pagerank DESC
LIMIT 1

// 4. ¿Cuáles son los 3 personajes que más importan para la conexión de todos en el grafo? 

call gds.graph.project("betweenness",
                        "Personaje",
                        "CONNECTED_TO")

CALL gds.betweenness.write('betweenness', { writeProperty: 'betweenness' })
YIELD centralityDistribution, nodePropertiesWritten
RETURN centralityDistribution.min AS minimumScore, centralityDistribution.mean AS meanScore, nodePropertiesWritten

MATCH (p:Personaje)
RETURN p.Label as name, p.betweenness as betweenness
ORDER BY betweenness desc
LIMIT 3

// 5. ¿A qué personaje, si lo eliminaras, no afectaría en la conexión general del grafo? 

MATCH (p:Personaje)
RETURN p.Label as name, p.betweenness as betweenness
ORDER BY betweenness asc
LIMIT 1

// 6. ¿Qué personajes están abajo de la media en conexiones totales? 

MATCH (p:Personaje)
WITH AVG(p.degree) as degree_mean
MATCH (p:Personaje)
WHERE p.degree < degree_mean
RETURN COLLECT(p.Label) as personajes

// 7. ¿Cómo es afectada la conectividad del grafo si eliminamos a Jon Snow del grafo? 

MATCH (p:Personaje {Label: "Jon"})-[r]-(other)
WITH p, COLLECT(r) AS relationships
FOREACH (r IN relationships | DELETE r)
DELETE p

call gds.graph.project("graphNoJon",
                        "Personaje",
                        "CONNECTED_TO")

MATCH (a), (b)
WHERE id(a) <> id(b)
WITH a, b, shortestPath((a)-[*]-(b)) AS path
RETURN length(path) AS diametro
ORDER BY diametro DESC
LIMIT 1

// 8. ¿Cuáles serían los 5 personajes que más rápido distribuirían una noticia importante a los demás? 

CALL gds.graph.project("closeness",
                        "Personaje",
                        "CONNECTED_TO")

CALL gds.closeness.write('closeness', { writeProperty: 'centrality' })
YIELD centralityDistribution, nodePropertiesWritten
RETURN centralityDistribution.min AS minimumScore, centralityDistribution.mean AS meanScore, nodePropertiesWritten

MATCH (p:Personaje)
RETURN p.Label as name, p.centrality as closeness
ORDER BY closeness desc
LIMIT 5

// 9. ¿Qué personajes reciben menos interacciones?

call gds.graph.project("in_degree",
                        "Personaje",
                        {CONNECTED_TO:{orientation: "REVERSE"}})

CALL gds.degree.write('in_degree', { writeProperty: 'in_degree' })
YIELD centralityDistribution, nodePropertiesWritten
RETURN centralityDistribution.min AS minimumScore, centralityDistribution.mean AS meanScore, nodePropertiesWritten

MATCH (p:Personaje)
RETURN p.Label as name, p.in_degree as in_degree
ORDER BY in_degree asc
LIMIT 1

// 10. ¿Qué personaje puede ser un “centro de poder oculto”? (tiene poder, más no es uno de los protagonistas) 

MATCH (p:Personaje)
RETURN p.Label AS NAME, p.pagerank as pr
ORDER BY pr desc

// 11. Si eliminamos al personaje con mayor conectividad, ¿cómo responde el grafo? 

MATCH (p:Personaje {Label: "Robb"})-[r]-(other)
WITH p, COLLECT(r) AS relationships
FOREACH (r IN relationships | DELETE r)
DELETE p

MATCH (a), (b)
WHERE id(a) <> id(b)
WITH a, b, shortestPath((a)-[*]-(b)) AS path
RETURN length(path) AS diametro
ORDER BY diametro DESC
LIMIT 1

// 12. ¿Existe algún personaje con muchas interacciones, pero con poco poder social?

MATCH (p:Personaje)
WITH  AVG(p.degree) as avg_degree, AVG(p.pagerank) as avg_pr
MATCH (p:Personaje)
WHERE p.degree > avg_degree and p.pagerank < avg_pr
RETURN p.Label as name, p.degree as degree, p.pagerank as pr

// 13. Si hubiera una enfermedad terminal, ¿quién nos convendría que se enfermara primero para que no se propagara el virus? 

MATCH (p:Personaje)
RETURN p.Label as name, p.centrality as centrality
ORDER BY centrality asc
LIMIT 1

// 14. ¿Los personajes con más conexiones tienden a ser los de mayor peso político? 

MATCH (p:Personaje)
RETURN p.Label as name, p.degree as degree
ORDER BY degree desc
LIMIT 6

MATCH (p:Personaje)
RETURN p.Label as name, p.pagerank as pagerank
ORDER BY pagerank desc
LIMIT 6

// 15. ¿Existe algún personaje con no tantas conexiones, pero conexiones de mucho poder? 

MATCH (p:Personaje)
WITH  AVG(p.degree) as avg_degree, AVG(p.pagerank) as avg_pr
MATCH (p:Personaje)
WHERE p.degree < avg_degree and p.pagerank > avg_pr
RETURN p.Label as name, p.degree as degree, p.pagerank as pr