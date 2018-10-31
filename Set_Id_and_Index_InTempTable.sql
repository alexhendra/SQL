select identity(int, 1,1) as id_num, * into #inserted   
from inserted  
create index ix_id_num on #inserted (id_num) 
