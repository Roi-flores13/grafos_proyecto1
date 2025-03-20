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
