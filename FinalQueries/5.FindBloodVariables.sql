set search_path to sepsis; 
DROP VIEW IF EXISTS VASO_IDs CASCADE; 
CREATE VIEW VASO_IDS AS
(
	select distinct hadm_id from 
		(select distinct hadm_id from mimiciiifull.inputevents_mv
		  where itemid in(5752,30119,30309,30044,221289,3112,221906,30047,30120,30306,30042,221653,5329,30043,30307,221662,6752,221749)
		  and hadm_id in (select distinct hadm_id from mimiciiifull.vitalsfirstday) 
		  
		  UNION 
		  select distinct hadm_id from mimiciiifull.inputevents_cv
		  where itemid in(5752,30119,30309,30044,221289,3112,221906,30047,30120,30306,30042,221653,5329,30043,30307,221662,6752,221749)
		  and hadm_id in (select distinct hadm_id from mimiciiifull.vitalsfirstday) 
		 ) as inputcv
);


drop view if exists heights cascade;
create view heights as
(
select  mimiciiifull.vitalsfirstday.subject_id, 
		case when height is not null then 
				height
			
			when virtualtable.chart_heights is not null then
				case
				when unit like '%cm%' then
					chart_heights*0.01
				when unit like '%in%' then
					chart_heights*0.0254
				else null end
			else null end as height
			
		 from mimiciiifull.vitalsfirstday  left join (
			 select min(valuenum) as chart_heights, subject_id , 'in' as unit
			 	from mimiciiifull.chartevents 
	 			where itemid in(920,1394,226707)  and valuenum is not null 
		 		group by subject_id 
		 union
			 select min(valuenum) as chart_heights, subject_id, 'cm' as unit
			 	from mimiciiifull.chartevents
		 		where itemid in(226730) and valuenum is not null
		 		group by subject_id
		 union 
		 	select max(heightfreetext) as chartheights, subject_id, 'in' as unit
		 		from sepsis.notes
		 		group by subject_id
		 ) as virtualtable on virtualtable.subject_id = vitalsfirstday.subject_id	

);



--select * from  vitalandoutcomes_ss  where height_min is not null ; 


drop materialized view if exists blood_variables cascade; 

create materialized view blood_variables as
(
select seps.*
	,
	case when cardiacoutput_min is not null then
				cardiacoutput_min
			when strokevolume_min is not null and heartrate_min is not null then
				strokevolume_min * heartrate_min
			else null end as cardiacoutput_min_everywhere


	, 	case when cardiacoutput_max is not null then
				cardiacoutput_max
			when strokevolume_max is not null and heartrate_max is not null then
				strokevolume_max * heartrate_max
			else null end as cardiacoutput_max_everywhere
								
	,  --calculating cao2 when it's not available, putting everything in one column
	
	
		 case when cao2 is not null then
			 				cao2
	 	 when cao2 is null and haemoglobin is not null and sao2 is not null 
	 	 										and pao2_min is not null then 
 			 		1.36 * haemoglobin * sao2*0.01 + 0.0031 * pao2_min
		 else null end as cao2_everywhere
		
		,
		case when neutrophils_min is not null and lymphocytes_min is not null
					 and neutrophils_min <> 0  and lymphocytes_min <> 0 then
				(neutrophils_min / lymphocytes_min)
			else null end as neutrophils_lymphocyte_ratio_min

		,
		case when neutrophils_max is not null and lymphocytes_max is not null
					 and neutrophils_max <> 0  and lymphocytes_max <> 0 then
				(neutrophils_max / lymphocytes_max)
			else null end as neutrophils_lymphocyte_ratio_max	    
		, 

	   	case 
	     		when fio2_min is not null then fio2_min
	    	 		else blood.fio2 end as fio2_min_everywhere
	    ,  
	    case
	   		when paco2_max is not null then paco2_max
	     		else blood.pco2 end as paco2_max_everywhere
					
	from mimiciiifull.vitalsfirstday as seps left join 
		 mimiciiifull.bloodgasfirstday as blood 
				on blood.hadm_id = seps.hadm_id
); 
