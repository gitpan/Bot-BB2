CREATE TABLE factoids( 
	factoid_id INTEGER PRIMARY KEY AUTOINCREMENT, 
	normalized_subject VARCHAR(200), 
	subject VARCHAR(200), 
	copula VARCHAR(50), 
	predicate VARCHAR(250), 
	time INTEGER, 
	nick VARCHAR(100)
);
