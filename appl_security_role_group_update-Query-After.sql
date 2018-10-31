/******************************************************************  
* TRIGGER : appl_security_role_group_update
* PURPOSE  : Logging on update
* CREATED : No history  
* SAMPLE    :   select * into #temp from dbo.appl_security_role_group where rid='10FF3B9E-E748-42C7-9777-01B317048FAC'

--select * from #temp

 update #temp set created_by='FMI\atandraw'
  update #temp set group_id='976A607A-FB84-4CB8-9775-0281BB0882F0'
  update #temp set rid='C24B6B87-FFBA-4D45-8FDF-000EF7B30CEB'

 insert into appl_security_role_group
 select * from #temp

 update appl_security_role_group set created_by='FMI\atandraw3'
 where created_by='FMI\atandraw2'

select * from dbo.audit_log_header where  
 table_name='appl_security_role_group'
 and process_type='U' and created_by='FMI\atandraw3'

select * from audit_log_detail where 
 new_field_value_1 like '%FMI\atandraw2%'

* MODIFIED   
* DATE    AUTHOR    DESCRIPTION  
*------------------------------------------------------------------  
* 26 Jan 2018  atandraw   Remove references to undocumented system tables  
* 29-10-2018 apanjait PTFI_SQL_2016: Fixing Remove references to undocumented system tables (this query from customappsdbna)
*******************************************************************/  

ALTER trigger dbo.appl_security_role_group_update on dbo.appl_security_role_group  
for update  
as  
  
set nocount on
declare @ObjID int   
declare @strTableName varchar(512)  
  
set @ObjID = (select [parent_object_id] from sys.objects where [object_id] = @@PROCID)   
set @strTableName = (select OBJECT_NAME(@ObjID))   
  
if (not exists(select * from dbo.vw_audit_settings (NOLOCK) where table_name = @strTableName and is_audited = 1))  
 return  
  
declare @field_name varchar(512)  
declare @act_status varchar(1)  
declare @activity_id uniqueidentifier  
declare @strQuery varchar(8000)  
declare @intUserType as smallint  
declare @intId as integer  
  
set @act_status = 'U'  
  
select identity(int, 1,1) as id_num, * into #inserted   
from inserted  
create index ix_id_num on #inserted (id_num)  
  
select identity(int, 1,1) as id_num, * into #deleted  
from deleted  
create index ix_id_num on #deleted (id_num)  
  
declare insertedCursor cursor for  
select id_num from #inserted  
  
open insertedCursor  
  
fetch next from insertedCursor into @intId  
  
while (@@fetch_status <> -1)  
begin  
 set @activity_id = newID()  
  
 insert into dbo.audit_log_header   
 select @activity_id, @strTableName, @act_status, getDate(), created_by  
 from #inserted where id_num = convert(varchar(10), @intId)  
   
 declare fieldCursor cursor for   
 select b.name, b.user_type_id  
 from sys.objects a(nolock) inner join  
   sys.columns b(nolock)  
 on a.type = 'U'  
   and a.name = @strTableName  
   and a.[object_id] = b.[object_id]  
   
 open fieldCursor  
   
 fetch next from fieldCursor into @field_name, @intUserType  
   
 while @@fetch_status = 0  
 begin  
  exec dbo.spaudit_admin_execute_sql @act_status, @activity_id, @field_name, @intId, @intUserType   
   
  -- Get the next field name.  
  fetch next from fieldCursor into @field_name, @intUserType  
 end  
   
 close fieldCursor  
 deallocate fieldCursor  
  
 fetch next from insertedCursor into @intId  
end  
  
close insertedCursor  
deallocate insertedCursor  
  
set nocount off
