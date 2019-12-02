

DROP FUNCTION IF EXISTS find_overlap_gap_make_run_cmd(table_to_analyze_ varchar, table_name_result_prefix_ varchar);

DROP FUNCTION IF EXISTS find_overlap_gap_make_run_cmd(
table_to_analyze_ varchar, -- The table to analyze 
geo_collumn_name_ varchar, 	-- the name of geometry column on the table to analyze	
srid_ int, -- the srid for the given geo column on the table analyze
table_name_result_prefix_ varchar -- This is the prefix used for the result tables
);

CREATE OR REPLACE FUNCTION find_overlap_gap_make_run_cmd(
table_to_analyze_ varchar, -- The table to analyze 
geo_collumn_name_ varchar, 	-- the name of geometry column on the table to analyze	
srid_ int, -- the srid for the given geo column on the table analyze
table_name_result_prefix_ varchar -- This is the prefix used for the result tables
) RETURNS SETOF text 
AS $$DECLARE
	command_string text;
	num_rows int;

	part text;	
	id_list_tmp int[];
	this_list_id int;
	
	func_call text;
	
	-- the number of cells created in the grid
	num_cells int;


	max_rows_in_each_cell int = 5000; -- this is the max number rows that intersects with box before it's split into 4 new boxes 

	overlapgap_overlap varchar = table_name_result_prefix_ || '_overlap'; -- The schema.table name for the overlap/intersects found in each cell 
	overlapgap_gap varchar = table_name_result_prefix_ || '_gap'; -- The schema.table name for the gaps/holes found in each cell 
	overlapgap_grid varchar  = table_name_result_prefix_ || '_grid'; -- The schema.table name of the grid that will be created and used to break data up in to managle pieces
	overlapgap_boundery varchar = table_name_result_prefix_ || '_boundery'; -- The schema.table name the outer boundery of the data found in each cell 

BEGIN

	
	--select * from geometry_columns;
	
	--Generate command to create grid
	--'SELECT find_overlap_gap_init('sl_lop.sk_grl_flate','geo',4258,10,'overlapgap_overlap','overlapgap_gap','overlapgap_grid','overlapgap_boundery')";
	command_string := FORMAT('SELECT find_overlap_gap_init(%s,%s,%s,%s,%s,%s,%s,%s)',
	quote_literal(table_to_analyze_),
	quote_literal(geo_collumn_name_),
	srid_,
	max_rows_in_each_cell,
	quote_literal(overlapgap_overlap),
	quote_literal(overlapgap_gap),
	quote_literal(overlapgap_grid),
	quote_literal(overlapgap_boundery)
	);
		
	-- display the string
	RAISE NOTICE '%', command_string;
	-- execute the string
	EXECUTE command_string INTO num_cells;

	-- Get list id from grid and make id list
	command_string := FORMAT('SELECT array_agg(DISTINCT id) from %s',overlapgap_grid);
		-- display the string
	RAISE NOTICE '%', command_string;
	-- execute the string
	EXECUTE command_string INTO id_list_tmp;


	-- create a table to hold call stack
	DROP TABLE IF EXISTS return_call_list;
	CREATE TEMP TABLE return_call_list (func_call text);

	-- create call for each cell
	FOREACH this_list_id IN ARRAY id_list_tmp
	LOOP 
		func_call := FORMAT('SELECT find_overlap_gap_single_cell(%s,%s,%s,%s,%s,%s)',quote_literal(table_to_analyze_),quote_literal(geo_collumn_name_),srid_,
		quote_literal(table_name_result_prefix_),this_list_id,num_cells);
		INSERT INTO return_call_list(func_call) VALUES (func_call);
	END loop;

	-- return call for each cell
	RETURN QUERY select * FROM return_call_list;

END;
$$
LANGUAGE plpgsql;

GRANT EXECUTE on FUNCTION find_overlap_gap_make_run_cmd(table_to_analyze_ varchar, -- The table to analyze 
geo_collumn_name_ varchar, 	-- the name of geometry column on the table to analyze	
srid_ int, -- the srid for the given geo column on the table analyze
table_name_result_prefix_ varchar -- This is the prefix used for the result tables
) TO public;
