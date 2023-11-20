select 
	a.agent_id,
	b.fullname,
	b.phonenumber as contact,
	b.onecode,
	c.current_occupation,
	d. app_not_start as "Application Not Started",
	d.app_inc as "Application Incomplete",
	d.act_pending as "Activation Pending",
	d.docp as "SDocumentation Pending",
	d.pdfrmbrand as "Approval Pending from Brand",
	d.vkyc as "Video KYC Pending",
	d.enach as "Sign/emandate agreement pending"
from
(
	select
		agent_id 
	from
	(
		select 
			agent_id,
			case 
				when ((Sale_Done = 0 and lead_completed >= 1) or (Sale_Done = 0 and lead_Added >= 1) or (Sale_Done = 1)) then 'Targetted Agent'
				else 'Not Targetted'
			end as Agent_category
		from
		(
			select 
				user_id as agent_id,
				count(id) filter(where status in ('fulfilled','pfulfilled','fullfilled')) as Sale_Done,
				count(id) filter(where status in ('rejected','leadadded')) as lead_Added,
				count(id) filter(where status in ('fulfilled','pfulfilled','fullfilled''rejected','leadadded'))	as lead_completed
			from tbl a
			where cast(created_at as date) between cast('2023-01-01' as date) and cast('2023-01-31' as date) and is_current = true
			group by 1
		)a
	)a
	where 
		Agent_category in ('Targetted Agent')
		and agent_id in
		(    ------------- B1 & B2 Agents----------------------
			select
				agent_id
			from
			(
				select 
				agent_id,
				partner_id,
				case 
					when ((Sale_Done = 0 and lead_completed >= 1) or (Sale_Done = 1 and lead_completed >= 2 )) then 'B1'
					when Sale_Done >= 2 then 'B1'
					else 'Not Required'
				end as Bucket_December
				from
				(
					select 
						user_id as agent_id,
						partner_id,
						count(id) filter(where status in ('fulfilled','pfulfilled','fullfilled')) as Sale_Done,
						count(id) filter(where status in ('rejected','leadadded','actnreqrd','expired')) as lead_Added,
						count(id) filter(where status in ('fulfilled','pfulfilled','fullfilled''rejected'))	as lead_completed
					from 
					tbl 
					where cast(created_at as date) between cast('2022-12-01' as date) and cast('2022-12-31' as date) and is_current = true
					group by 1,2
				)a
			)a
			where Bucket_December in ('B1','B2')
		)
	group by 1
)a 
left join 
	onecodeuser b
on
	b.id = a.agent_id
left join
	user_kyc c
on
	c.user_id = a.agent_id
left join
(                    ---------- Application Status Data -------------------
	select 
		a.user_id,
		count(case when b.journey_status in ('Application Not Started') then b.lead_id end) as app_not_start,
		count(case when b.journey_status in ('Application Incomplete') then b.lead_id end) as app_inc,
		count(case when b.journey_status in ('Activation Pending') then b.lead_id end) as act_pending,
		count(case when b.journey_status in ('Documentation Pending') then b.lead_id end) as docp,
		count(case when b.journey_status in ('AApproval Pending from Brand') then b.lead_id end) as pdfrmbrand,
		count(case when b.journey_status in ('Video KYC Pending') then b.lead_id end) as vkyc,
		count(case when b.journey_status in ('Sign/emandate agreement pending') then b.lead_id end) as enach
	from
	(select * from tbl where is_current = true) a 
	left join
	(select
	distinct
	tbl_id as lead_id
	, c.status as journey_status
	from oc_ask a
	left join tbl2 b
	on a.ask_code = b.ask_code
	left join partner_lead_status c
	on b.ask_category_code = c.status_code
	where a.is_resolved =false  and c.partner_id = 0 and c.category = 'stages' and b.partner_id not in (157) and ask_category_code is not null)b
	on b.lead_id = a.id
	where date(a.created_at) between date('2022-12-01') and date('2022-12-31')
	group by 1
)d
on
	d.user_id = a.agent_id;