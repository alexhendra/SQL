exec sp_MSforeachdb  'USE [?]; select distinct ''?'' AS DB,object_name(id) as SP from syscomments where text like ''%GET_VISIT_VISITOR_ID%'''
