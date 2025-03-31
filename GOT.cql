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
SET r.weight = toInteger(row[2])

////////// EDA

// 1. Cuantos nodos totales hay?
MATCH (n:Personaje)
RETURN COUNT(n) AS Total_Nodos

// 2. Cuantas relaciones hay?
MATCH (n)-[r]->(n2)
RETURN COUNT(DISTINCT(r))

// 3. Tipos de relaciones y sus propiedades
CALL db.schema.relTypeProperties

// 3. Esquema general del grafo
CALL db.schema.visualization

// 4. Tipos de nodos y sus propiedades
CALL db.schema.nodeTypeProperties

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


// Preguntas de comunidad
// 1. ¿Se mantienen las casas en las comunidades de Louvain?
//Creación del subgrafo
CALL gds.graph.project(
    'myGraphWeighted',
    'Personaje',
    {CONNECTED_TO:{properties:'weight'}}
); 

//Aplicamos Louvain
CALL gds.louvain.write('myGraphWeighted', {writeProperty: 'louvainWeighted'})
YIELD communityCount, modularity, modularities

// 2. ¿Cómo cambian las comunidades si no especificamos el peso en Louvain?
//Subgrafo
CALL gds.graph.project(
    'myGraphUnweighted',
    'Personaje',
    'CONNECTED_TO'
); 

//Propiedad
CALL gds.louvain.write('myGraphUnweighted', {writeProperty: 'louvainUnweighted'})
YIELD communityCount, modularity, modularities

//3. ¿Hay comunidades dependiendo de la ubicación geográfica? 
MATCH(n)
RETURN n.louvainWeighted, collect(n.Label)

//4. ¿Qué nos dicen las comunidades intermedias de Louvain? 
CALL gds.louvain.stream('myGraphWeighted', { includeIntermediateCommunities: true })
YIELD nodeId, communityId, intermediateCommunityIds
RETURN gds.util.asNode(nodeId).Label AS name, communityId, intermediateCommunityIds
ORDER BY name ASC

//5. ¿Se pueden detectar personajes que estén realizando alguna conspiración o traición? 
CALL gds.scc.write('myGraphWeighted', {writeProperty:'communitySCC'})
YIELD componentCount, componentDistribution

MATCH(n)
RETURN n.communitySCC, COUNT(n), COLLECT(n.Label)

//Probamos si hay ciclos:
MATCH (n)-[*]->(n) RETURN COUNT(n);

//6. ¿Cuáles son las comunidades conectadas más fuertemente? 
MATCH(n)
RETURN n.communitySCC, COUNT(n), collect(n.Label)

//7. ¿Cuál comunidad existe sin conexiones muy fuertes? 
CALL gds.graph.project(
    'myUndirectedGraph',
    'Personaje',
    {CONNECTED_TO: {orientation:'UNDIRECTED', Properties:'weight'}}
)

CALL gds.wcc.write('myUndirectedGraph', {writeProperty:'communityWCC'})
YIELD componentCount, componentDistribution

// 8 y 9.	¿Cuántos colores son necesarios con el k1Coloring?, ¿Cómo se ve el grafo después del k1Color?
CALL gds.k1coloring.write('myUndirectedGraph', {writeProperty: 'k1color'})
YIELD nodeCount, colorCount, ranIterations, didConverge

//10. ¿Cuántos triángulos hay al iniciar la temporada?  
CALL gds.graph.project(
    'myUndirectedGraph',
    'Personaje',
    {CONNECTED_TO: {orientation:'UNDIRECTED', Properties:'weight'}}
)

CALL gds.triangleCount.write('myUndirectedGraph', {writeProperty: 'triangles'})
YIELD globalTriangleCount, nodeCount

MATCH(p:Personaje)
SET p.triangles = p.triangles + 1
RETURN p.triangles, count(p.Label), collect(p.Label)
ORDER BY COUNT(p.Label) DESC


//11. ¿Cuál es personaje con más relaciones triangulares de la temporada 3? 
MATCH(n)
RETURN n.Label AS name, n.triangles
ORDER BY n.triangles DESC, name ASC
LIMIT 1

//12. ¿Cómo se agrupan las comunidades con labelPropagation sin una semilla? 
CALL gds.labelPropagation.write('myGraphWeighted', {writeProperty:'labelPropagation'})
YIELD communityCount, ranIterations, didConverge;

//13. ¿Cómo se ven las comunidades del labelPropagation después de usar a “Jon Snow” como semilla? 
MATCH(p:Personaje)
WHERE p.Label = 'Jon'
SET p.comunidadInicial = p.labelPropagation

CALL gds.graph.project(
    'myAlterGraph',
    'Personaje',
    {CONNECTED_TO: {orientation:'UNDIRECTED'}},
    {nodeProperties:['comunidadInicial']}
)

CALL gds.labelPropagation.write('myAlterGraph', {
    seedProperty:'comunidadInicial',
    writeProperty:'labelPropagationSeeded'
    })
YIELD communityCount, ranIterations, didConverge;

//14. ¿Cómo afecta la muerte de Robb Stark a las comunidades? 
MATCH(r:Personaje{Label:'Robb'})
DETACH DELETE p;

CALL gds.graph.project(
    'myGraphWeightedwoRobb',
    'Personaje',
    {CONNECTED_TO:{properties:'weight'}}
); 

CALL gds.labelPropagation.write('myGraphWeightedwoRobb', {writeProperty:'labelPropagation'})
YIELD communityCount, ranIterations, didConverge;

//15. ¿Como cambian las comunidades después de la boda roja? 
MATCH (p:Personaje)
WHERE p.Label IN ['Catelyn', 'Talisa', 'Aegon']
DETACH DELETE p;

CALL gds.graph.project(
    'myGraphWeightedRedWed',
    'Personaje',
    {CONNECTED_TO:{properties:'weight'}}
); 

CALL gds.labelPropagation.write('myGraphWeightedRedWed', {writeProperty:'labelPropagationRedWed'})
YIELD communityCount, ranIterations, didConverge;