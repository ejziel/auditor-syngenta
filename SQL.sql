select *
from (
  select
			concat('Crédito indevido em ', ifnull(critica_1,''),' ',ifnull(critica_2,''),' ',ifnull(critica_3,''),' ',ifnull(critica_4,''),' ',ifnull(critica_5,'')) critica,
            empresa,
            estabelecimento,
            cod_estabelecimento,
            tipo_estabelecimento,
            cst,
            ncm_serv,
            desc_ncm_serv,
            data_fiscal,
            produto,
            desc_produto,
            doc_num,
            nota_fiscal,
            cfop,
            regra_cfop,
            movimento,
            chave_nfe,
            valor_contabil,
            valor_icms,
            valor_ipi,
            valor_pis,
            valor_cofins,
			critica_1,
			critica_2,
			critica_3,
			critica_4,
			critica_5
  from   (
          select 	#! A LOGICA DE 'ENTRADA' FOI MOVIDA PARA CA
					case when sub.movimento = 'ENTRADA' and ifnull(credito_icms,1) = 0 and valor_icms  > 0 then '[ICMS]' else null end critica_1,
					case when sub.movimento = 'ENTRADA' and ifnull(credito_ipi,1) = 0 and valor_ipi  > 0 then '[IPI]' else null end critica_2,
					case when sub.movimento = 'ENTRADA' and ifnull(credito_pis,1) = 0 and valor_pis  > 0 then '[PIS]' else null end critica_3,
					case when sub.movimento = 'ENTRADA' and ifnull(credito_cofins,1) = 0 and valor_cofins  > 0 then '[COFINS]' else null end critica_4,
					#! Esta critica nao tem o filtro e sera aplicada a entradas e saidas
					case when cfop_status = 'Verificar' then '[CFOP - Regra Filial]' else null end critica_5,
					sub.*
          from   (
                  select  left(cp.name,2) empresa,
                          right(b.code,4) estabelecimento,
                          b.code cod_estabelecimento,
                          b.type tipo_estabelecimento,
			              CST cst,
                          COD_NCM_LEI_COMPL ncm_serv,
                          DSC_NCM_LEI_COMPL desc_ncm_serv,
                          DATA_FISCAL data_fiscal,
                          COD_PRODUTO produto,
                          DESCRICAO_PROD desc_produto,
                          NUM_CONTROLE_DOCTO doc_num,
                          NUM_DOCFIS nota_fiscal,
                          COD_CFOP cfop,
                          case when cast(COD_CFOP as int64) < 4000 then 'ENTRADA' else 'SAIDA' end movimento,
                          CHAVE_ELETRONICA chave_nfe,
			  			  VLR_CONTAB_ITEM valor_contabil,
                          VLR_TRIBUTO_ICMS valor_icms,
                          VLR_TRIBUTO_IPI valor_ipi,
                          VLR_PIS valor_pis,
                          VLR_COFINS valor_cofins,
                          cfs.status cfop_status,
                          rc.regra regra_cfop
                  from      `org_90_7536cf.z_livro_fiscal` lf
                  inner join `turimmanager.org__707ed0.cfops` cf on cf.cfop = cast(lpad(trim(COD_CFOP),4,'0') as int64)
                  inner join `org_90_7536cf.bq_branch` b on b.federal_id = lf.CNPJ_ESTAB
                  inner join `org_90_7536cf.bq_company` cp on cast(cp.id as int64) = cast(b.company_id as int64)
                  left join  `org_90_7536cf.z_regra_cfop` rc on rc.cfop = lpad(trim(lf.COD_CFOP),4,'0')
                  left join  `org_90_7536cf.z_regra_cfop_filial_status` cfs on cfs.atividade_empresa = b.type and cfs.regra = rc.regra
                  #! A CLAUSULA WHERE FOI REMOVIDA DAQUI
                  #! and FORMAT_DATE('%Y-%m-01',lf.DATA_FISCAL) = '%period%'
                ) sub inner join
                (	select code branch_code,
                           max(case when z_branch_icms_credit = 'Yes' then 1 
                                when z_branch_icms_credit = 'No' then 0
                                else 0
                           end) credito_icms,
                           max(case when z_branch_ipi_credit = 'Yes' then 1 
                                when z_branch_ipi_credit = 'No' then 0
                                else 0
                           end) credito_ipi,
                           max(case when z_branch_pis_cofins_credit = 'Yes' then 1 
                                when z_branch_pis_cofins_credit = 'No' then 0
                                else 0
                           end) credito_pis,
                           max(case when z_branch_pis_cofins_credit = 'Yes' then 1 
                                when z_branch_pis_cofins_credit = 'No' then 0
                                else 0
                           end) credito_cofins
                    from `org_90_7536cf.bq_branch`
                    where _status = 'active'
                    group by code
				) tr on tr.branch_code = sub.cod_estabelecimento
          ) sub
          where  	(critica_1 is not null
					 and not exists( select 1
									 from   org_90_7536cf.z_credito_filial_excecao e
									 where  e.cfop = sub.cfop
									 and    e.branch_code = sub.cod_estabelecimento
									 and 	e.excecao = 'ICMS'))
               or 	(critica_2 is not null
					 and not exists( select 1
									 from   org_90_7536cf.z_credito_filial_excecao e
									 where  e.cfop = sub.cfop
									 and    e.branch_code = sub.cod_estabelecimento
									 and 	e.excecao = 'IPI'))
               or 	(critica_3 is not null
					 and not exists( select 1
									 from   org_90_7536cf.z_credito_filial_excecao e
									 where  e.cfop = sub.cfop
									 and    e.branch_code = sub.cod_estabelecimento
									 and 	(e.excecao = 'PIS' or e.excecao = 'PISCOFINS')))
               or 	(critica_4 is not null
					 and not exists( select 1
									 from   org_90_7536cf.z_credito_filial_excecao e
									 where  e.cfop = sub.cfop
									 and    e.branch_code = sub.cod_estabelecimento
									 and 	(e.excecao = 'COFINS' or e.excecao = 'PISCOFINS')))
               or 	critica_5 is not null 
    ) sub
    where critica <> ''
    and not exists( select 1 
    				from   org_90_7536cf.z_credito_filial_excecao e
                    where  e.cfop = sub.cfop
                    and    e.branch_code = sub.cod_estabelecimento
                  )
    and not exists( select 1 
    				from   org_90_7536cf.z_credito_filial_excecao e
                    where  e.ncm = sub.ncm_serv
                    and    e.branch_code = sub.cod_estabelecimento
                  )
	and not exists( select 1 
    				from   org_90_7536cf.z_credito_filial_excecao e
                    where  e.servico = sub.ncm_serv
                    and    e.branch_code = sub.cod_estabelecimento
                  )