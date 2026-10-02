# LGPD + Snowflake: Guia Completo de Conformidade

Treinamento passo a passo para implementar conformidade com a **Lei Geral de Protecao de Dados (Lei 13.709/2018)** usando recursos nativos do Snowflake. Cobre desde fundamentos legais ate operacao completa com 9 modulos executaveis.

---

## O que esta incluso

| Arquivo | Descricao |
|---------|-----------|
| `LGPD_SNOW.html` | Guia interativo com teoria, SQL executavel e sidebar navegavel (dark mode) |
| `LGPD_SNOW.sql` | SQL consolidado (1100+ linhas) para execucao direta no Snowsight |

## Modulos

| # | Modulo | Artigos LGPD | Recursos Snowflake |
|---|--------|--------------|-------------------|
| 1 | Fundamentos da LGPD | Arts. 1-5, 46 | Visao geral da arquitetura |
| 2 | Governanca e RBAC | Arts. 41, 46, 50 | Roles, grants, segregacao de funcoes |
| 3 | Classificacao de Dados | Arts. 5, 11 | `SYSTEM$CLASSIFY`, tags de sistema |
| 4 | Tags Customizadas | Arts. 6, 7, 15 | Object tagging, heranca, bases legais |
| 5 | Mascaramento Dinamico | Arts. 46, 6-X | Masking policies, tag-based masking |
| 6 | Row Access Policies | Arts. 6-I, 46 | RAP, limitacao de finalidade |
| 7 | Projection Policies | Arts. 6-X, 11, 46 | Projection policies (FAIL/NULLIFY), minimizacao |
| 8 | Direitos do Titular (DSAR) | Arts. 18, 19 | Stored procedures, portabilidade, anonimizacao |
| 9 | Auditoria e Conformidade | Arts. 37-38, 48, 50 | ACCESS_HISTORY, alertas, relatorios |

## Defesa em Profundidade

O treinamento implementa tres camadas independentes de protecao na mesma tabela:

```
Camada 1: Row Access Policy   -> filtra LINHAS (quem ve quais registros)
Camada 2: Projection Policy   -> bloqueia COLUNAS no output (quem ve quais campos)
Camada 3: Masking Policy       -> transforma VALORES visiveis (como os dados aparecem)
```

## Pre-requisitos

- Snowflake Enterprise Edition (ou superior)
- Role `ACCOUNTADMIN` ou `SYSADMIN` para configuracao inicial
- Snowsight (interface web) para execucao interativa

## Como usar

1. **Configure as variaveis** no inicio do arquivo SQL:
   ```sql
   SET LGPD_USER      = '<SEU_USUARIO>';
   SET LGPD_DPO_EMAIL = '<SEU_EMAIL>';
   ```

2. **Execute sequencialmente** cada modulo no Snowsight (Modulo 2 antes de 3, etc.)

3. **Ou abra o HTML** (`LGPD_SNOW.html`) no navegador para o guia interativo com teoria e SQL lado a lado

## Limpeza

Para remover todos os objetos criados pelo treinamento:

```sql
USE ROLE ACCOUNTADMIN;
DROP DATABASE IF EXISTS LGPD_GOVERNANCE;
DROP DATABASE IF EXISTS EMPRESA_DEMO;
DROP WAREHOUSE IF EXISTS LGPD_TRAINING_WH;
DROP ROLE IF EXISTS LGPD_DPO;
DROP ROLE IF EXISTS LGPD_PRIVACY_ADMIN;
DROP ROLE IF EXISTS LGPD_DATA_STEWARD;
DROP ROLE IF EXISTS LGPD_ANALYST;
DROP ROLE IF EXISTS HR_ANALYST;
DROP ROLE IF EXISTS MARKETING_ANALYST;
DROP ROLE IF EXISTS FINANCE_ANALYST;
DROP NOTIFICATION INTEGRATION IF EXISTS LGPD_NOTIFICATIONS;
```

## Licenca

[MIT](LICENSE)
