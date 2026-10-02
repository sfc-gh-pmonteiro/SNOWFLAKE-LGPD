-- =============================================================================
-- LGPD + SNOWFLAKE: GUIA COMPLETO DE CONFORMIDADE
-- =============================================================================
-- Lei 13.709/2018 | Snowflake Enterprise Edition+
-- Arquivo consolidado com todos os 8 modulos
--
-- INSTRUCOES:
--   1. Configure as 2 variaveis abaixo com seu usuario e email
--   2. Execute cada modulo sequencialmente (modulo 2 antes de 3, etc.)
--   3. Cada secao pode ser executada individualmente no Snowsight
-- =============================================================================


-- #############################################################################
-- CONFIGURACAO: substitua os valores abaixo antes de executar
-- #############################################################################

SET LGPD_USER      = '<SEU_USUARIO>';          -- Ex: 'JSILVA'
SET LGPD_DPO_EMAIL = '<SEU_EMAIL>';             -- Ex: 'dpo@empresa.com.br'


-- #############################################################################
-- MODULO 2: INFRAESTRUTURA DE GOVERNANCA E RBAC
-- Arts. 41, 46, 50
-- #############################################################################

-- -------------------------------------------------------------
-- 2.1: Database e Schemas de Governanca
-- -------------------------------------------------------------
-- Um database centralizado evita fragmentacao de politicas

USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS LGPD_GOVERNANCE
  COMMENT = 'Database centralizado para governanca LGPD';

CREATE SCHEMA IF NOT EXISTS LGPD_GOVERNANCE.TAGS
  COMMENT = 'Tags customizadas para classificacao LGPD';

CREATE SCHEMA IF NOT EXISTS LGPD_GOVERNANCE.POLICIES
  COMMENT = 'Masking policies e Row Access Policies';

CREATE SCHEMA IF NOT EXISTS LGPD_GOVERNANCE.AUDIT
  COMMENT = 'Logs de DSAR, procedimentos e alertas';

-- Warehouse dedicado para o treinamento (X-Small = custo minimo)
CREATE WAREHOUSE IF NOT EXISTS LGPD_TRAINING_WH
  WAREHOUSE_SIZE = 'X-SMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  COMMENT = 'Warehouse dedicado para treinamento LGPD';


-- -------------------------------------------------------------
-- 2.2: Roles LGPD
-- -------------------------------------------------------------
-- Segregacao de funcoes (SoD) conforme Art. 50 da LGPD

USE ROLE USERADMIN;

-- Encarregado (DPO) - Art. 41
CREATE ROLE IF NOT EXISTS LGPD_DPO
  COMMENT = 'Encarregado de Protecao de Dados (DPO) - Art. 41 LGPD';

-- Administrador de Privacidade - cria e gerencia politicas
CREATE ROLE IF NOT EXISTS LGPD_PRIVACY_ADMIN
  COMMENT = 'Cria e gerencia masking policies e row access policies';

-- Data Steward - aplica tags e monitora
CREATE ROLE IF NOT EXISTS LGPD_DATA_STEWARD
  COMMENT = 'Aplica tags LGPD e monitora conformidade';

-- Analista - acesso restrito a dados anonimizados
CREATE ROLE IF NOT EXISTS LGPD_ANALYST
  COMMENT = 'Acesso a dados com mascaramento aplicado';

-- Hierarquia de roles
GRANT ROLE LGPD_PRIVACY_ADMIN TO ROLE LGPD_DPO;
GRANT ROLE LGPD_DATA_STEWARD  TO ROLE LGPD_DPO;
GRANT ROLE LGPD_ANALYST        TO ROLE LGPD_PRIVACY_ADMIN;


-- -------------------------------------------------------------
-- 2.3: Privilegios de governanca
-- -------------------------------------------------------------

USE ROLE ACCOUNTADMIN;

-- Privilegios para LGPD_DATA_STEWARD (tags)
GRANT USAGE ON DATABASE LGPD_GOVERNANCE TO ROLE LGPD_DATA_STEWARD;
GRANT USAGE ON SCHEMA LGPD_GOVERNANCE.TAGS TO ROLE LGPD_DATA_STEWARD;
GRANT CREATE TAG ON SCHEMA LGPD_GOVERNANCE.TAGS TO ROLE LGPD_DATA_STEWARD;
GRANT APPLY TAG ON ACCOUNT TO ROLE LGPD_DATA_STEWARD;

-- Privilegios para LGPD_PRIVACY_ADMIN (policies)
GRANT USAGE ON DATABASE LGPD_GOVERNANCE TO ROLE LGPD_PRIVACY_ADMIN;
GRANT USAGE ON ALL SCHEMAS IN DATABASE LGPD_GOVERNANCE TO ROLE LGPD_PRIVACY_ADMIN;
GRANT CREATE MASKING POLICY ON SCHEMA LGPD_GOVERNANCE.POLICIES
  TO ROLE LGPD_PRIVACY_ADMIN;
GRANT CREATE ROW ACCESS POLICY ON SCHEMA LGPD_GOVERNANCE.POLICIES
  TO ROLE LGPD_PRIVACY_ADMIN;
GRANT APPLY MASKING POLICY ON ACCOUNT TO ROLE LGPD_PRIVACY_ADMIN;
GRANT APPLY ROW ACCESS POLICY ON ACCOUNT TO ROLE LGPD_PRIVACY_ADMIN;
GRANT CREATE PROJECTION POLICY ON SCHEMA LGPD_GOVERNANCE.POLICIES
  TO ROLE LGPD_PRIVACY_ADMIN;
GRANT APPLY PROJECTION POLICY ON ACCOUNT TO ROLE LGPD_PRIVACY_ADMIN;

-- Privilegios para LGPD_DPO (acesso ao Governance Dashboard)
GRANT DATABASE ROLE SNOWFLAKE.GOVERNANCE_VIEWER TO ROLE LGPD_DPO;
GRANT DATABASE ROLE SNOWFLAKE.OBJECT_VIEWER TO ROLE LGPD_DPO;

-- Atribuir role LGPD_DPO ao usuario do treinamento
GRANT ROLE LGPD_DPO TO USER IDENTIFIER($LGPD_USER);

-- Warehouse: sem isso, nenhum role LGPD consegue executar queries
GRANT USAGE ON WAREHOUSE LGPD_TRAINING_WH TO ROLE LGPD_DPO;
GRANT USAGE ON WAREHOUSE LGPD_TRAINING_WH TO ROLE LGPD_PRIVACY_ADMIN;
GRANT USAGE ON WAREHOUSE LGPD_TRAINING_WH TO ROLE LGPD_DATA_STEWARD;
GRANT USAGE ON WAREHOUSE LGPD_TRAINING_WH TO ROLE LGPD_ANALYST;

-- LGPD_DPO: acesso ao AUDIT schema para DSAR
GRANT USAGE ON SCHEMA LGPD_GOVERNANCE.AUDIT TO ROLE LGPD_DPO;
GRANT CREATE TABLE ON SCHEMA LGPD_GOVERNANCE.AUDIT TO ROLE LGPD_DPO;
GRANT CREATE PROCEDURE ON SCHEMA LGPD_GOVERNANCE.AUDIT TO ROLE LGPD_DPO;
GRANT CREATE ALERT ON SCHEMA LGPD_GOVERNANCE.AUDIT TO ROLE LGPD_DPO;
GRANT EXECUTE ALERT ON ACCOUNT TO ROLE LGPD_DPO;

-- LGPD_PRIVACY_ADMIN: CREATE TABLE para tabela ACCESS_MAPPING (Modulo 6)
GRANT CREATE TABLE ON SCHEMA LGPD_GOVERNANCE.POLICIES
  TO ROLE LGPD_PRIVACY_ADMIN;


-- #############################################################################
-- MODULO 3: DESCOBERTA E CLASSIFICACAO DE DADOS
-- Arts. 5, 11
-- #############################################################################

-- -------------------------------------------------------------
-- 3.1: Tabela de exemplo com dados pessoais brasileiros
-- -------------------------------------------------------------

USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS EMPRESA_DEMO;
GRANT USAGE ON DATABASE EMPRESA_DEMO TO ROLE LGPD_ANALYST;
CREATE SCHEMA IF NOT EXISTS EMPRESA_DEMO.DADOS_CLIENTES;
GRANT USAGE ON SCHEMA EMPRESA_DEMO.DADOS_CLIENTES TO ROLE LGPD_ANALYST;

CREATE OR REPLACE TABLE EMPRESA_DEMO.DADOS_CLIENTES.CLIENTES (
  ID              NUMBER AUTOINCREMENT PRIMARY KEY,
  NOME            STRING    COMMENT 'Nome completo do titular',
  CPF             STRING    COMMENT 'Cadastro de Pessoa Fisica',
  EMAIL           STRING    COMMENT 'Endereco de email',
  TELEFONE        STRING    COMMENT 'Telefone com DDD',
  DATA_NASCIMENTO DATE      COMMENT 'Data de nascimento',
  ENDERECO        STRING    COMMENT 'Endereco residencial',
  CIDADE          STRING,
  ESTADO          STRING,
  CEP             STRING,
  GENERO          STRING    COMMENT 'Dado pessoal sensivel (Art. 11)',
  ETNIA           STRING    COMMENT 'Dado pessoal sensivel (Art. 11)',
  DEPARTAMENTO    STRING    COMMENT 'Departamento interno',
  DATA_CADASTRO   TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);

GRANT SELECT ON TABLE EMPRESA_DEMO.DADOS_CLIENTES.CLIENTES TO ROLE LGPD_ANALYST;

-- Inserir dados ficticios para demonstracao
INSERT INTO EMPRESA_DEMO.DADOS_CLIENTES.CLIENTES
  (NOME, CPF, EMAIL, TELEFONE, DATA_NASCIMENTO, ENDERECO, CIDADE, ESTADO, CEP, GENERO, ETNIA, DEPARTAMENTO)
VALUES
  ('Ana Silva',       '123.456.789-00', 'ana.silva@email.com',    '(11) 98765-4321', '1990-03-15', 'Rua das Flores, 100',     'Sao Paulo',      'SP', '01310-100', 'Feminino',  'Parda',  'RH'),
  ('Carlos Oliveira', '987.654.321-00', 'carlos.oliv@email.com',  '(21) 91234-5678', '1985-07-22', 'Av. Atlantica, 500',      'Rio de Janeiro',  'RJ', '22070-002', 'Masculino', 'Branca', 'FINANCEIRO'),
  ('Maria Santos',    '456.789.123-00', 'maria.santos@email.com', '(31) 99876-5432', '1992-11-08', 'Rua da Liberdade, 250',   'Belo Horizonte',  'MG', '30130-000', 'Feminino',  'Negra',  'MARKETING'),
  ('Joao Pereira',    '321.654.987-00', 'joao.p@empresa.com.br',  '(41) 93456-7890', '1988-01-30', 'Av. Batel, 1500',         'Curitiba',        'PR', '80420-090', 'Masculino', 'Branca', 'RH'),
  ('Beatriz Lima',    '654.321.987-00', 'bea.lima@empresa.com.br','(51) 97654-3210', '1995-06-12', 'Rua dos Andradas, 800',   'Porto Alegre',    'RS', '90020-007', 'Feminino',  'Parda',  'FINANCEIRO');


-- -------------------------------------------------------------
-- 3.1b: Grants cross-DB (dependem de EMPRESA_DEMO existir)
-- -------------------------------------------------------------

USE ROLE ACCOUNTADMIN;

-- Acesso cross-DB para aplicar tags/policies em tabelas de negocio
GRANT USAGE ON DATABASE EMPRESA_DEMO TO ROLE LGPD_DATA_STEWARD;
GRANT USAGE ON SCHEMA EMPRESA_DEMO.DADOS_CLIENTES TO ROLE LGPD_DATA_STEWARD;
GRANT USAGE ON DATABASE EMPRESA_DEMO TO ROLE LGPD_PRIVACY_ADMIN;
GRANT USAGE ON SCHEMA EMPRESA_DEMO.DADOS_CLIENTES TO ROLE LGPD_PRIVACY_ADMIN;
GRANT SELECT ON TABLE EMPRESA_DEMO.DADOS_CLIENTES.CLIENTES
  TO ROLE LGPD_PRIVACY_ADMIN;

-- LGPD_DPO: DML para procedures DSAR
GRANT USAGE ON DATABASE EMPRESA_DEMO TO ROLE LGPD_DPO;
GRANT USAGE ON SCHEMA EMPRESA_DEMO.DADOS_CLIENTES TO ROLE LGPD_DPO;
GRANT SELECT, INSERT, UPDATE, DELETE
  ON TABLE EMPRESA_DEMO.DADOS_CLIENTES.CLIENTES TO ROLE LGPD_DPO;
GRANT CREATE STAGE ON SCHEMA EMPRESA_DEMO.DADOS_CLIENTES TO ROLE LGPD_DPO;


-- -------------------------------------------------------------
-- 3.2: Classificacao automatica de dados
-- -------------------------------------------------------------
-- IMPORTANTE: Requer ACCOUNTADMIN para executar com auto_tag

USE ROLE ACCOUNTADMIN;

CALL SYSTEM$CLASSIFY(
  'EMPRESA_DEMO.DADOS_CLIENTES.CLIENTES',
  {'auto_tag': true}
);


-- -------------------------------------------------------------
-- 3.3: Revisar tags de sistema aplicadas
-- -------------------------------------------------------------

SELECT *
FROM TABLE(
  EMPRESA_DEMO.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS(
    'EMPRESA_DEMO.DADOS_CLIENTES.CLIENTES', 'TABLE'
  )
)
WHERE TAG_NAME IN ('SEMANTIC_CATEGORY', 'PRIVACY_CATEGORY')
ORDER BY COLUMN_NAME, TAG_NAME;


-- #############################################################################
-- MODULO 4: TAGS CUSTOMIZADAS PARA LGPD
-- Arts. 6, 7, 15
-- #############################################################################

-- -------------------------------------------------------------
-- 4.1: Tags customizadas LGPD
-- -------------------------------------------------------------

USE ROLE LGPD_DATA_STEWARD;
USE SCHEMA LGPD_GOVERNANCE.TAGS;

-- Categoria do dado conforme LGPD Art. 5
CREATE OR REPLACE TAG LGPD_DATA_CATEGORY
  ALLOWED_VALUES
    'DADO_PESSOAL',
    'DADO_PESSOAL_SENSIVEL',
    'DADO_ANONIMIZADO',
    'NAO_PESSOAL'
  COMMENT = 'Classificacao do dado conforme Art. 5 da LGPD';

-- Base legal para o tratamento (Art. 7)
CREATE OR REPLACE TAG LGPD_BASE_LEGAL
  ALLOWED_VALUES
    'CONSENTIMENTO',
    'OBRIGACAO_LEGAL',
    'EXECUCAO_POLITICAS_PUBLICAS',
    'PESQUISA',
    'EXECUCAO_CONTRATO',
    'EXERCICIO_DIREITOS',
    'PROTECAO_VIDA',
    'TUTELA_SAUDE',
    'INTERESSE_LEGITIMO',
    'PROTECAO_CREDITO'
  COMMENT = 'Base legal para tratamento conforme Art. 7 da LGPD';

-- Finalidade do tratamento (Art. 6, I)
CREATE OR REPLACE TAG LGPD_FINALIDADE
  COMMENT = 'Descricao da finalidade do tratamento (Art. 6, I)';

-- Periodo de retencao em dias (Art. 15-16)
CREATE OR REPLACE TAG LGPD_RETENCAO
  COMMENT = 'Periodo de retencao em dias (Art. 15-16)';

-- Controlador responsavel (Art. 5, VI)
CREATE OR REPLACE TAG LGPD_CONTROLADOR
  COMMENT = 'Nome do controlador de dados (Art. 5, VI)';

-- Operador responsavel (Art. 5, VII)
CREATE OR REPLACE TAG LGPD_OPERADOR
  COMMENT = 'Nome do operador de dados (Art. 5, VII)';


-- -------------------------------------------------------------
-- 4.2: Aplicar tags na tabela
-- -------------------------------------------------------------
-- NOTA: LGPD_DATA_CATEGORY e aplicada por COLUNA (nao na tabela)
-- para evitar conflito com tag-based masking em colunas nao-PII
-- como DEPARTAMENTO (usado pela Row Access Policy no Modulo 6).

-- Tags de metadados no nivel da tabela (heranca para todas as colunas)
ALTER TABLE EMPRESA_DEMO.DADOS_CLIENTES.CLIENTES SET TAG
  LGPD_GOVERNANCE.TAGS.LGPD_BASE_LEGAL    = 'CONSENTIMENTO',
  LGPD_GOVERNANCE.TAGS.LGPD_FINALIDADE    = 'Cadastro de clientes para prestacao de servicos',
  LGPD_GOVERNANCE.TAGS.LGPD_RETENCAO      = '1825',
  LGPD_GOVERNANCE.TAGS.LGPD_CONTROLADOR   = 'Empresa Demo Ltda';

-- LGPD_DATA_CATEGORY aplicada individualmente nas colunas PII
ALTER TABLE EMPRESA_DEMO.DADOS_CLIENTES.CLIENTES MODIFY COLUMN
  NOME SET TAG LGPD_GOVERNANCE.TAGS.LGPD_DATA_CATEGORY = 'DADO_PESSOAL';
ALTER TABLE EMPRESA_DEMO.DADOS_CLIENTES.CLIENTES MODIFY COLUMN
  CPF SET TAG LGPD_GOVERNANCE.TAGS.LGPD_DATA_CATEGORY = 'DADO_PESSOAL';
ALTER TABLE EMPRESA_DEMO.DADOS_CLIENTES.CLIENTES MODIFY COLUMN
  EMAIL SET TAG LGPD_GOVERNANCE.TAGS.LGPD_DATA_CATEGORY = 'DADO_PESSOAL';
ALTER TABLE EMPRESA_DEMO.DADOS_CLIENTES.CLIENTES MODIFY COLUMN
  TELEFONE SET TAG LGPD_GOVERNANCE.TAGS.LGPD_DATA_CATEGORY = 'DADO_PESSOAL';
ALTER TABLE EMPRESA_DEMO.DADOS_CLIENTES.CLIENTES MODIFY COLUMN
  DATA_NASCIMENTO SET TAG LGPD_GOVERNANCE.TAGS.LGPD_DATA_CATEGORY = 'DADO_PESSOAL';
ALTER TABLE EMPRESA_DEMO.DADOS_CLIENTES.CLIENTES MODIFY COLUMN
  ENDERECO SET TAG LGPD_GOVERNANCE.TAGS.LGPD_DATA_CATEGORY = 'DADO_PESSOAL';


-- -------------------------------------------------------------
-- 4.3: Override no nivel da coluna para dados sensiveis
-- -------------------------------------------------------------

ALTER TABLE EMPRESA_DEMO.DADOS_CLIENTES.CLIENTES MODIFY COLUMN
  GENERO SET TAG LGPD_GOVERNANCE.TAGS.LGPD_DATA_CATEGORY = 'DADO_PESSOAL_SENSIVEL';

ALTER TABLE EMPRESA_DEMO.DADOS_CLIENTES.CLIENTES MODIFY COLUMN
  ETNIA SET TAG LGPD_GOVERNANCE.TAGS.LGPD_DATA_CATEGORY = 'DADO_PESSOAL_SENSIVEL';


-- -------------------------------------------------------------
-- 4.4: Verificar tags aplicadas
-- -------------------------------------------------------------

SELECT *
FROM TABLE(
  EMPRESA_DEMO.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS(
    'EMPRESA_DEMO.DADOS_CLIENTES.CLIENTES', 'TABLE'
  )
)
WHERE TAG_DATABASE = 'LGPD_GOVERNANCE'
ORDER BY COLUMN_NAME, TAG_NAME;

SELECT SYSTEM$GET_TAG(
  'LGPD_GOVERNANCE.TAGS.LGPD_BASE_LEGAL',
  'EMPRESA_DEMO.DADOS_CLIENTES.CLIENTES',
  'TABLE'
);


-- #############################################################################
-- MODULO 5: POLITICAS DE MASCARAMENTO DINAMICO
-- Arts. 46, 6-X
-- #############################################################################

-- -------------------------------------------------------------
-- 5.1a: Masking Policy para CPF
-- -------------------------------------------------------------
-- Formato: 123.456.789-00 -> ***.456.789-**

USE ROLE LGPD_PRIVACY_ADMIN;

CREATE OR REPLACE MASKING POLICY LGPD_GOVERNANCE.POLICIES.MASK_CPF
  AS (val STRING) RETURNS STRING ->
  CASE
    WHEN IS_ROLE_IN_SESSION('LGPD_DPO') THEN val
    WHEN IS_ROLE_IN_SESSION('LGPD_PRIVACY_ADMIN') THEN val
    ELSE CONCAT(
      '***.',
      COALESCE(SUBSTR(val, 5, 3), '***'),
      '.',
      COALESCE(SUBSTR(val, 9, 3), '***'),
      '-**'
    )
  END
  COMMENT = 'Mascara CPF para roles nao autorizadas (Art. 46 LGPD)';


-- -------------------------------------------------------------
-- 5.1b: Masking Policy para Email
-- -------------------------------------------------------------
-- ana.silva@email.com -> *****@email.com

CREATE OR REPLACE MASKING POLICY LGPD_GOVERNANCE.POLICIES.MASK_EMAIL
  AS (val STRING) RETURNS STRING ->
  CASE
    WHEN IS_ROLE_IN_SESSION('LGPD_DPO') THEN val
    WHEN IS_ROLE_IN_SESSION('LGPD_PRIVACY_ADMIN') THEN val
    ELSE REGEXP_REPLACE(val, '.+\\@', '*****@')
  END
  COMMENT = 'Mascara parte local do email (Art. 46 LGPD)';


-- -------------------------------------------------------------
-- 5.1c: Masking Policy para Telefone
-- -------------------------------------------------------------
-- (11) 98765-4321 -> (**) *****-4321

CREATE OR REPLACE MASKING POLICY LGPD_GOVERNANCE.POLICIES.MASK_PHONE
  AS (val STRING) RETURNS STRING ->
  CASE
    WHEN IS_ROLE_IN_SESSION('LGPD_DPO') THEN val
    ELSE CONCAT('(**) *****-', RIGHT(val, 4))
  END
  COMMENT = 'Mascara telefone mantendo ultimos 4 digitos';


-- -------------------------------------------------------------
-- 5.1d: Masking Policies genericas
-- -------------------------------------------------------------

-- STRING generico (nomes, enderecos, dados sensiveis)
CREATE OR REPLACE MASKING POLICY LGPD_GOVERNANCE.POLICIES.MASK_PII_STRING
  AS (val STRING) RETURNS STRING ->
  CASE
    WHEN IS_ROLE_IN_SESSION('LGPD_DPO') THEN val
    WHEN IS_ROLE_IN_SESSION('LGPD_PRIVACY_ADMIN') THEN val
    ELSE '***PROTEGIDO***'
  END
  COMMENT = 'Mascaramento generico para strings com dados pessoais';

-- NUMBER generico (idade, salario, etc.)
CREATE OR REPLACE MASKING POLICY LGPD_GOVERNANCE.POLICIES.MASK_PII_NUMBER
  AS (val NUMBER) RETURNS NUMBER ->
  CASE
    WHEN IS_ROLE_IN_SESSION('LGPD_DPO') THEN val
    ELSE NULL
  END
  COMMENT = 'Mascaramento generico para numeros com dados pessoais';

-- DATE generico (data de nascimento, etc.)
CREATE OR REPLACE MASKING POLICY LGPD_GOVERNANCE.POLICIES.MASK_PII_DATE
  AS (val DATE) RETURNS DATE ->
  CASE
    WHEN IS_ROLE_IN_SESSION('LGPD_DPO') THEN val
    ELSE DATE_FROM_PARTS(1900, 01, 01)
  END
  COMMENT = 'Mascaramento generico para datas com dados pessoais';


-- -------------------------------------------------------------
-- 5.2: Aplicar masking policies diretamente
-- -------------------------------------------------------------

ALTER TABLE EMPRESA_DEMO.DADOS_CLIENTES.CLIENTES MODIFY COLUMN
  CPF SET MASKING POLICY LGPD_GOVERNANCE.POLICIES.MASK_CPF;

ALTER TABLE EMPRESA_DEMO.DADOS_CLIENTES.CLIENTES MODIFY COLUMN
  EMAIL SET MASKING POLICY LGPD_GOVERNANCE.POLICIES.MASK_EMAIL;

ALTER TABLE EMPRESA_DEMO.DADOS_CLIENTES.CLIENTES MODIFY COLUMN
  TELEFONE SET MASKING POLICY LGPD_GOVERNANCE.POLICIES.MASK_PHONE;

ALTER TABLE EMPRESA_DEMO.DADOS_CLIENTES.CLIENTES MODIFY COLUMN
  DATA_NASCIMENTO SET MASKING POLICY LGPD_GOVERNANCE.POLICIES.MASK_PII_DATE;


-- -------------------------------------------------------------
-- 5.3: Tag-based masking para protecao automatica
-- -------------------------------------------------------------
-- Ao associar masking policies a uma tag, TODAS as colunas
-- tagueadas com essa tag sao automaticamente protegidas.

USE ROLE LGPD_PRIVACY_ADMIN;

ALTER TAG LGPD_GOVERNANCE.TAGS.LGPD_DATA_CATEGORY SET
  MASKING POLICY LGPD_GOVERNANCE.POLICIES.MASK_PII_STRING,
  MASKING POLICY LGPD_GOVERNANCE.POLICIES.MASK_PII_NUMBER,
  MASKING POLICY LGPD_GOVERNANCE.POLICIES.MASK_PII_DATE;

-- IMPORTANTE: Policies aplicadas diretamente a coluna
-- tem PRECEDENCIA sobre tag-based masking policies.
-- Ou seja, CPF usa MASK_CPF (direta), nao MASK_PII_STRING (tag).


-- -------------------------------------------------------------
-- 5.4: Validacao do mascaramento
-- -------------------------------------------------------------
-- IMPORTANTE: Desabilitar secondary roles para testar isoladamente.
-- Com secondary roles ativas, IS_ROLE_IN_SESSION('LGPD_DPO') retorna
-- TRUE mesmo usando LGPD_ANALYST, pois LGPD_DPO esta ativo como
-- secondary role. Isso anula o mascaramento no ambiente de teste.

USE SECONDARY ROLES NONE;

-- Como LGPD_DPO: deve ver dados completos
USE ROLE LGPD_DPO;
SELECT NOME, CPF, EMAIL, TELEFONE, DATA_NASCIMENTO
FROM EMPRESA_DEMO.DADOS_CLIENTES.CLIENTES
LIMIT 3;
-- Resultado esperado: dados originais visiveis

-- Como LGPD_ANALYST: deve ver dados mascarados
USE ROLE LGPD_ANALYST;
SELECT NOME, CPF, EMAIL, TELEFONE, DATA_NASCIMENTO
FROM EMPRESA_DEMO.DADOS_CLIENTES.CLIENTES
LIMIT 3;
-- Resultado esperado:
-- NOME: ***PROTEGIDO***
-- CPF: ***.456.789-**
-- EMAIL: *****@email.com
-- TELEFONE: (**) *****-4321
-- DATA_NASCIMENTO: 1900-01-01

-- Restaurar secondary roles apos o teste
USE SECONDARY ROLES ALL;


-- #############################################################################
-- MODULO 6: ROW ACCESS POLICIES
-- Arts. 6-I, 46
-- #############################################################################

-- -------------------------------------------------------------
-- 6.0: Roles por departamento para testar a RAP
-- -------------------------------------------------------------

USE ROLE USERADMIN;

CREATE ROLE IF NOT EXISTS HR_ANALYST
  COMMENT = 'Analista de RH';
CREATE ROLE IF NOT EXISTS MARKETING_ANALYST
  COMMENT = 'Analista de Marketing';
CREATE ROLE IF NOT EXISTS FINANCE_ANALYST
  COMMENT = 'Analista Financeiro';

-- Atribuir ao usuario do treinamento para teste
GRANT ROLE HR_ANALYST TO USER IDENTIFIER($LGPD_USER);
GRANT ROLE MARKETING_ANALYST TO USER IDENTIFIER($LGPD_USER);
GRANT ROLE FINANCE_ANALYST TO USER IDENTIFIER($LGPD_USER);

-- Conceder warehouse + acesso a tabela
USE ROLE ACCOUNTADMIN;
GRANT USAGE ON WAREHOUSE LGPD_TRAINING_WH TO ROLE HR_ANALYST;
GRANT USAGE ON WAREHOUSE LGPD_TRAINING_WH TO ROLE MARKETING_ANALYST;
GRANT USAGE ON WAREHOUSE LGPD_TRAINING_WH TO ROLE FINANCE_ANALYST;
GRANT USAGE ON DATABASE EMPRESA_DEMO TO ROLE HR_ANALYST;
GRANT USAGE ON DATABASE EMPRESA_DEMO TO ROLE MARKETING_ANALYST;
GRANT USAGE ON DATABASE EMPRESA_DEMO TO ROLE FINANCE_ANALYST;
GRANT USAGE ON SCHEMA EMPRESA_DEMO.DADOS_CLIENTES TO ROLE HR_ANALYST;
GRANT USAGE ON SCHEMA EMPRESA_DEMO.DADOS_CLIENTES TO ROLE MARKETING_ANALYST;
GRANT USAGE ON SCHEMA EMPRESA_DEMO.DADOS_CLIENTES TO ROLE FINANCE_ANALYST;
GRANT SELECT ON TABLE EMPRESA_DEMO.DADOS_CLIENTES.CLIENTES TO ROLE HR_ANALYST;
GRANT SELECT ON TABLE EMPRESA_DEMO.DADOS_CLIENTES.CLIENTES TO ROLE MARKETING_ANALYST;
GRANT SELECT ON TABLE EMPRESA_DEMO.DADOS_CLIENTES.CLIENTES TO ROLE FINANCE_ANALYST;


-- -------------------------------------------------------------
-- 6.1: Tabela de mapeamento acesso x finalidade
-- -------------------------------------------------------------

USE ROLE LGPD_PRIVACY_ADMIN;

CREATE OR REPLACE TABLE LGPD_GOVERNANCE.POLICIES.ACCESS_MAPPING (
  ROLE_NAME       STRING   COMMENT 'Role Snowflake',
  DEPARTMENT      STRING   COMMENT 'Departamento permitido',
  ALLOWED_PURPOSE STRING   COMMENT 'Finalidade do acesso',
  REGION          STRING   COMMENT 'Regiao permitida'
);

INSERT INTO LGPD_GOVERNANCE.POLICIES.ACCESS_MAPPING VALUES
  ('HR_ANALYST',        'RH',         'GESTAO_PESSOAL',    'BRASIL'),
  ('MARKETING_ANALYST', 'MARKETING',  'CAMPANHAS',         'BRASIL'),
  ('FINANCE_ANALYST',   'FINANCEIRO', 'FATURAMENTO',       'BRASIL'),
  ('LGPD_DPO',          'ALL',        'GOVERNANCA',        'ALL'),
  ('LGPD_PRIVACY_ADMIN','ALL',        'GOVERNANCA',        'ALL');


-- -------------------------------------------------------------
-- 6.2: Row Access Policy com limitacao de finalidade
-- -------------------------------------------------------------

CREATE OR REPLACE ROW ACCESS POLICY
  LGPD_GOVERNANCE.POLICIES.RAP_PURPOSE_LIMITATION
  AS (department STRING) RETURNS BOOLEAN ->
  -- DPO e Privacy Admin veem tudo
  IS_ROLE_IN_SESSION('LGPD_DPO')
  OR IS_ROLE_IN_SESSION('LGPD_PRIVACY_ADMIN')
  -- Outros roles: somente dados do departamento autorizado
  OR EXISTS (
    SELECT 1
    FROM LGPD_GOVERNANCE.POLICIES.ACCESS_MAPPING am
    WHERE am.ROLE_NAME = CURRENT_ROLE()
      AND (am.DEPARTMENT = department OR am.DEPARTMENT = 'ALL')
  )
  COMMENT = 'Limita acesso por departamento conforme principio de finalidade (Art. 6, I)';


-- -------------------------------------------------------------
-- 6.3: Aplicar RAP a tabela
-- -------------------------------------------------------------

ALTER TABLE EMPRESA_DEMO.DADOS_CLIENTES.CLIENTES
  ADD ROW ACCESS POLICY LGPD_GOVERNANCE.POLICIES.RAP_PURPOSE_LIMITATION
  ON (DEPARTAMENTO);


-- -------------------------------------------------------------
-- 6.4: Validacao da RAP
-- -------------------------------------------------------------
-- Desabilitar secondary roles para testar isoladamente

USE SECONDARY ROLES NONE;

-- Como LGPD_DPO: deve ver TODAS as linhas
USE ROLE LGPD_DPO;
SELECT NOME, DEPARTAMENTO FROM EMPRESA_DEMO.DADOS_CLIENTES.CLIENTES;
-- Resultado: 5 registros (todos os departamentos)

-- Como HR_ANALYST: deve ver somente departamento RH
USE ROLE HR_ANALYST;
SELECT NOME, DEPARTAMENTO FROM EMPRESA_DEMO.DADOS_CLIENTES.CLIENTES;
-- Resultado: 2 registros (Ana Silva e Joao Pereira - ambos RH)

-- Como FINANCE_ANALYST: deve ver somente FINANCEIRO
USE ROLE FINANCE_ANALYST;
SELECT NOME, DEPARTAMENTO FROM EMPRESA_DEMO.DADOS_CLIENTES.CLIENTES;
-- Resultado: 2 registros (Carlos Oliveira e Beatriz Lima)

-- Restaurar secondary roles
USE SECONDARY ROLES ALL;


-- #############################################################################
-- MODULO 7: POLITICAS DE PROJECAO (PROJECTION POLICIES)
-- Arts. 6-X, 11, 46
-- #############################################################################
-- Projection Policies controlam se uma coluna pode APARECER no resultado
-- final de uma query. Diferente do masking (que transforma o valor), a
-- projection policy IMPEDE que a coluna seja projetada.
--
-- Ordem de avaliacao: RAP (linhas) -> Projection (colunas) -> Masking (valores)
--
-- LGPD: Implementa minimizacao (Art. 6, X) e protecao extra para
-- dados sensiveis (Art. 11).

-- -------------------------------------------------------------
-- 7.1: Grants para Projection Policies
-- -------------------------------------------------------------
-- NOTA: Estes grants tambem constam no Modulo 2 para execucao
-- sequencial completa. Repetidos aqui para execucao independente.

USE ROLE ACCOUNTADMIN;
GRANT CREATE PROJECTION POLICY ON SCHEMA LGPD_GOVERNANCE.POLICIES
  TO ROLE LGPD_PRIVACY_ADMIN;
GRANT APPLY PROJECTION POLICY ON ACCOUNT TO ROLE LGPD_PRIVACY_ADMIN;


-- -------------------------------------------------------------
-- 7.2: Projection Policy — Bloqueio total (FAIL) para dados sensiveis
-- -------------------------------------------------------------
-- Colunas GENERO e ETNIA (Art. 11 — dados pessoais sensiveis):
-- Somente DPO e PRIVACY_ADMIN podem projetar.
-- Outros roles: query FALHA se tentar incluir a coluna no SELECT.

USE ROLE LGPD_PRIVACY_ADMIN;

CREATE OR REPLACE PROJECTION POLICY LGPD_GOVERNANCE.POLICIES.PROJ_SENSITIVE_BLOCK
  AS () RETURNS PROJECTION_CONSTRAINT ->
  CASE
    WHEN IS_ROLE_IN_SESSION('LGPD_DPO')
      THEN PROJECTION_CONSTRAINT(ALLOW => true)
    WHEN IS_ROLE_IN_SESSION('LGPD_PRIVACY_ADMIN')
      THEN PROJECTION_CONSTRAINT(ALLOW => true)
    ELSE PROJECTION_CONSTRAINT(ALLOW => false)
  END
  COMMENT = 'Bloqueia projecao de dados sensiveis para roles nao autorizadas (Art. 11 LGPD)';


-- -------------------------------------------------------------
-- 7.3: Projection Policy — NULLIFY para PII geral
-- -------------------------------------------------------------
-- Em vez de falhar a query, retorna NULL para a coluna protegida.
-- Util quando se deseja permitir a query mas ocultar a coluna.
-- Aplicaremos ao ENDERECO como exemplo de minimizacao (Art. 6, X).

CREATE OR REPLACE PROJECTION POLICY LGPD_GOVERNANCE.POLICIES.PROJ_PII_NULLIFY
  AS () RETURNS PROJECTION_CONSTRAINT ->
  CASE
    WHEN IS_ROLE_IN_SESSION('LGPD_DPO')
      THEN PROJECTION_CONSTRAINT(ALLOW => true)
    WHEN IS_ROLE_IN_SESSION('LGPD_PRIVACY_ADMIN')
      THEN PROJECTION_CONSTRAINT(ALLOW => true)
    ELSE PROJECTION_CONSTRAINT(ALLOW => false, ENFORCEMENT => 'NULLIFY')
  END
  COMMENT = 'Retorna NULL para colunas PII nao autorizadas — minimizacao (Art. 6, X LGPD)';


-- -------------------------------------------------------------
-- 7.4: Aplicar Projection Policies as colunas
-- -------------------------------------------------------------

-- Dados sensiveis: bloqueio total (FAIL)
ALTER TABLE EMPRESA_DEMO.DADOS_CLIENTES.CLIENTES MODIFY COLUMN
  GENERO SET PROJECTION POLICY LGPD_GOVERNANCE.POLICIES.PROJ_SENSITIVE_BLOCK;

ALTER TABLE EMPRESA_DEMO.DADOS_CLIENTES.CLIENTES MODIFY COLUMN
  ETNIA SET PROJECTION POLICY LGPD_GOVERNANCE.POLICIES.PROJ_SENSITIVE_BLOCK;

-- PII geral: retorna NULL (NULLIFY)
ALTER TABLE EMPRESA_DEMO.DADOS_CLIENTES.CLIENTES MODIFY COLUMN
  ENDERECO SET PROJECTION POLICY LGPD_GOVERNANCE.POLICIES.PROJ_PII_NULLIFY;


-- -------------------------------------------------------------
-- 7.5: Validacao das Projection Policies
-- -------------------------------------------------------------
-- Desabilitar secondary roles para testar isoladamente

USE SECONDARY ROLES NONE;

-- Como LGPD_DPO: deve ver TODAS as colunas normalmente
USE ROLE LGPD_DPO;
SELECT NOME, GENERO, ETNIA, ENDERECO
FROM EMPRESA_DEMO.DADOS_CLIENTES.CLIENTES LIMIT 3;
-- Resultado esperado: dados visiveis para o DPO

-- Como LGPD_ANALYST: GENERO e ETNIA bloqueiam a query (FAIL)
USE ROLE LGPD_ANALYST;

-- IMPORTANTE: Esta query FALHA — descomente para testar:
-- SELECT GENERO FROM EMPRESA_DEMO.DADOS_CLIENTES.CLIENTES LIMIT 1;
-- Erro: "Projection policy does not allow column projection"

-- ENDERECO retorna NULL (enforcement NULLIFY)
SELECT NOME, ENDERECO FROM EMPRESA_DEMO.DADOS_CLIENTES.CLIENTES LIMIT 3;
-- Resultado esperado: ENDERECO = NULL em todas as linhas

-- IMPORTANTE: A coluna bloqueada AINDA pode ser usada em WHERE/JOIN!
-- A projection policy so afeta o OUTPUT final (SELECT list).
-- NOTA: O valor no WHERE e o valor MASCARADO (masking ja aplicou).
SELECT COUNT(*) AS TOTAL
FROM EMPRESA_DEMO.DADOS_CLIENTES.CLIENTES
WHERE GENERO IS NOT NULL;
-- Resultado: 2 (query nao falha; conta linhas com GENERO nao-nulo)

-- Restaurar secondary roles
USE SECONDARY ROLES ALL;


-- -------------------------------------------------------------
-- 7.6: Verificar todas as policies na tabela (visao consolidada)
-- -------------------------------------------------------------

USE ROLE ACCOUNTADMIN;
SELECT POLICY_NAME, POLICY_KIND, REF_COLUMN_NAME, POLICY_STATUS
FROM TABLE(EMPRESA_DEMO.INFORMATION_SCHEMA.POLICY_REFERENCES(
  ref_entity_name => 'EMPRESA_DEMO.DADOS_CLIENTES.CLIENTES',
  ref_entity_domain => 'TABLE'
))
ORDER BY REF_COLUMN_NAME, POLICY_KIND;


-- #############################################################################
-- MODULO 8: DIREITOS DO TITULAR (DSAR)
-- Arts. 18, 19
-- (anteriormente Modulo 7)
-- #############################################################################

-- -------------------------------------------------------------
-- 8.1: Tabela de log de requisicoes DSAR
-- -------------------------------------------------------------

USE ROLE LGPD_DPO;

CREATE OR REPLACE TABLE LGPD_GOVERNANCE.AUDIT.DSAR_LOG (
  REQUEST_ID    STRING DEFAULT UUID_STRING(),
  REQUEST_TYPE  STRING,
  TITULAR_ID    STRING    COMMENT 'CPF ou identificador do titular',
  REQUESTED_BY  STRING DEFAULT CURRENT_USER(),
  REQUESTED_AT  TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
  STATUS        STRING DEFAULT 'PENDENTE',
  COMPLETED_AT  TIMESTAMP_LTZ,
  DETAILS       VARIANT
)
COMMENT = 'Log de requisicoes de direitos do titular (Art. 18 LGPD)';


-- -------------------------------------------------------------
-- 8.2: Procedimento de Acesso aos Dados (Art. 18, II)
-- -------------------------------------------------------------

CREATE OR REPLACE PROCEDURE LGPD_GOVERNANCE.AUDIT.DSAR_ACCESS(
  TITULAR_CPF STRING
)
RETURNS TABLE()
LANGUAGE SQL
AS
$$
BEGIN
  -- Registrar a requisicao no log
  INSERT INTO LGPD_GOVERNANCE.AUDIT.DSAR_LOG
    (REQUEST_TYPE, TITULAR_ID, STATUS, COMPLETED_AT)
  VALUES
    ('ACESSO', :TITULAR_CPF, 'CONCLUIDO', CURRENT_TIMESTAMP());

  -- Retornar dados do titular
  LET rs RESULTSET := (
    SELECT ID, NOME, CPF, EMAIL, TELEFONE, DATA_NASCIMENTO,
           ENDERECO, CIDADE, ESTADO, CEP, DATA_CADASTRO
    FROM EMPRESA_DEMO.DADOS_CLIENTES.CLIENTES
    WHERE CPF = :TITULAR_CPF
  );
  RETURN TABLE(rs);
END;
$$;


-- -------------------------------------------------------------
-- 8.3: Procedimento de Correcao de Dados (Art. 18, III)
-- -------------------------------------------------------------

CREATE OR REPLACE PROCEDURE LGPD_GOVERNANCE.AUDIT.DSAR_CORRECTION(
  TITULAR_CPF   STRING,
  CAMPO         STRING,
  NOVO_VALOR    STRING
)
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
  -- Registrar a requisicao (usa SELECT em vez de VALUES para OBJECT_CONSTRUCT)
  INSERT INTO LGPD_GOVERNANCE.AUDIT.DSAR_LOG
    (REQUEST_TYPE, TITULAR_ID, DETAILS)
  SELECT 'CORRECAO', :TITULAR_CPF,
     OBJECT_CONSTRUCT('campo', :CAMPO, 'novo_valor', :NOVO_VALOR);

  -- Executar a correcao (campos permitidos)
  IF (:CAMPO = 'EMAIL') THEN
    UPDATE EMPRESA_DEMO.DADOS_CLIENTES.CLIENTES
    SET EMAIL = :NOVO_VALOR WHERE CPF = :TITULAR_CPF;
  ELSEIF (:CAMPO = 'TELEFONE') THEN
    UPDATE EMPRESA_DEMO.DADOS_CLIENTES.CLIENTES
    SET TELEFONE = :NOVO_VALOR WHERE CPF = :TITULAR_CPF;
  ELSEIF (:CAMPO = 'ENDERECO') THEN
    UPDATE EMPRESA_DEMO.DADOS_CLIENTES.CLIENTES
    SET ENDERECO = :NOVO_VALOR WHERE CPF = :TITULAR_CPF;
  ELSE
    RETURN 'Erro: Campo nao permitido para correcao via DSAR.';
  END IF;

  -- Atualizar status
  UPDATE LGPD_GOVERNANCE.AUDIT.DSAR_LOG
  SET STATUS = 'CONCLUIDO', COMPLETED_AT = CURRENT_TIMESTAMP()
  WHERE TITULAR_ID = :TITULAR_CPF
    AND REQUEST_TYPE = 'CORRECAO'
    AND STATUS = 'PENDENTE';

  RETURN CONCAT('Campo ', :CAMPO, ' corrigido com sucesso para o titular ', :TITULAR_CPF);
END;
$$;


-- -------------------------------------------------------------
-- 8.4: Procedimento de Eliminacao / Anonimizacao (Art. 18, VI)
-- -------------------------------------------------------------

CREATE OR REPLACE PROCEDURE LGPD_GOVERNANCE.AUDIT.DSAR_DELETE(
  TITULAR_CPF STRING
)
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
  -- Verificar se o titular existe
  LET cnt NUMBER := (
    SELECT COUNT(*) FROM EMPRESA_DEMO.DADOS_CLIENTES.CLIENTES
    WHERE CPF = :TITULAR_CPF
  );

  IF (:cnt = 0) THEN
    RETURN 'Erro: Titular nao encontrado.';
  END IF;

  -- Anonimizar dados pessoais (manter registro para integridade referencial)
  UPDATE EMPRESA_DEMO.DADOS_CLIENTES.CLIENTES
  SET
    NOME            = 'ANONIMIZADO',
    CPF             = 'XXX.XXX.XXX-XX',
    EMAIL           = CONCAT('anonimizado_', ID, '@removed.lgpd'),
    TELEFONE        = '(00) 00000-0000',
    DATA_NASCIMENTO = DATE_FROM_PARTS(1900, 01, 01),
    ENDERECO        = 'REMOVIDO',
    CIDADE          = 'REMOVIDO',
    ESTADO          = 'XX',
    CEP             = '00000-000',
    GENERO          = NULL,
    ETNIA           = NULL
  WHERE CPF = :TITULAR_CPF;

  -- Registrar no log
  INSERT INTO LGPD_GOVERNANCE.AUDIT.DSAR_LOG
    (REQUEST_TYPE, TITULAR_ID, STATUS, COMPLETED_AT)
  VALUES
    ('ELIMINACAO', :TITULAR_CPF, 'CONCLUIDO', CURRENT_TIMESTAMP());

  RETURN CONCAT('Dados do titular ', :TITULAR_CPF, ' anonimizados com sucesso.');
END;
$$;


-- -------------------------------------------------------------
-- 8.5: Procedimento de Portabilidade (Art. 18, V)
-- -------------------------------------------------------------

-- Criar stage para exportacao DSAR
CREATE STAGE IF NOT EXISTS EMPRESA_DEMO.DADOS_CLIENTES.DSAR_EXPORT
  COMMENT = 'Stage para exportacao de dados em requisicoes de portabilidade';

CREATE OR REPLACE PROCEDURE LGPD_GOVERNANCE.AUDIT.DSAR_PORTABILITY(
  TITULAR_CPF STRING
)
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
  -- Exportar dados para stage
  COPY INTO @EMPRESA_DEMO.DADOS_CLIENTES.DSAR_EXPORT/portabilidade/
  FROM (
    SELECT ID, NOME, CPF, EMAIL, TELEFONE, DATA_NASCIMENTO,
           ENDERECO, CIDADE, ESTADO, CEP, DATA_CADASTRO
    FROM EMPRESA_DEMO.DADOS_CLIENTES.CLIENTES
    WHERE CPF = :TITULAR_CPF
  )
  FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"')
  OVERWRITE = TRUE
  SINGLE = TRUE
  HEADER = TRUE;

  -- Registrar no log
  INSERT INTO LGPD_GOVERNANCE.AUDIT.DSAR_LOG
    (REQUEST_TYPE, TITULAR_ID, STATUS, COMPLETED_AT)
  VALUES
    ('PORTABILIDADE', :TITULAR_CPF, 'CONCLUIDO', CURRENT_TIMESTAMP());

  RETURN CONCAT('Dados exportados para @DSAR_EXPORT/portabilidade/ para o titular ', :TITULAR_CPF);
END;
$$;


-- -------------------------------------------------------------
-- 8.6: Validacao dos procedimentos DSAR
-- -------------------------------------------------------------

-- Teste: Direito de Acesso
CALL LGPD_GOVERNANCE.AUDIT.DSAR_ACCESS('123.456.789-00');

-- Teste: Direito de Correcao
CALL LGPD_GOVERNANCE.AUDIT.DSAR_CORRECTION(
  '123.456.789-00', 'EMAIL', 'ana.novo@email.com'
);

-- Teste: Direito de Portabilidade
CALL LGPD_GOVERNANCE.AUDIT.DSAR_PORTABILITY('987.654.321-00');

-- Verificar log de DSAR
SELECT * FROM LGPD_GOVERNANCE.AUDIT.DSAR_LOG
ORDER BY REQUESTED_AT DESC;


-- #############################################################################
-- MODULO 9: MONITORAMENTO, AUDITORIA E CONFORMIDADE
-- Arts. 37-38, 48, 50
-- (anteriormente Modulo 8)
-- #############################################################################

-- -------------------------------------------------------------
-- 9.1: Quem acessou dados pessoais nos ultimos 30 dias?
-- -------------------------------------------------------------
-- Usa ACCESS_HISTORY + QUERY_HISTORY para rastrear acessos (Art. 37)
-- NOTA: ACCESS_HISTORY nao tem ROLE_NAME; obter via JOIN com QUERY_HISTORY

USE ROLE ACCOUNTADMIN;

SELECT
  ah.USER_NAME,
  qh.ROLE_NAME,
  ah.QUERY_START_TIME,
  boa.VALUE:objectName::STRING AS OBJECT_ACCESSED,
  boa.VALUE:objectDomain::STRING AS OBJECT_TYPE,
  ah.QUERY_ID
FROM SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY ah
  JOIN SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY qh
    ON ah.QUERY_ID = qh.QUERY_ID
  ,LATERAL FLATTEN(input => ah.BASE_OBJECTS_ACCESSED) boa
WHERE ah.QUERY_START_TIME >= DATEADD('day', -30, CURRENT_TIMESTAMP())
  AND boa.VALUE:objectName::STRING ILIKE '%CLIENTES%'
ORDER BY ah.QUERY_START_TIME DESC
LIMIT 100;


-- -------------------------------------------------------------
-- 9.2: Quais tabelas TEM e quais NAO TEM tags LGPD?
-- -------------------------------------------------------------

SELECT
  t.TABLE_CATALOG AS DATABASE_NAME,
  t.TABLE_SCHEMA  AS SCHEMA_NAME,
  t.TABLE_NAME,
  t.ROW_COUNT,
  COALESCE(tr.TAG_VALUE, '*** SEM TAG ***') AS LGPD_CATEGORY,
  CASE
    WHEN tr.TAG_VALUE IS NOT NULL THEN 'CONFORME'
    ELSE 'PENDENTE'
  END AS STATUS_CONFORMIDADE
FROM SNOWFLAKE.ACCOUNT_USAGE.TABLES t
LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES tr
  ON t.TABLE_CATALOG = tr.OBJECT_DATABASE
  AND t.TABLE_SCHEMA = tr.OBJECT_SCHEMA
  AND t.TABLE_NAME = tr.OBJECT_NAME
  AND tr.TAG_NAME = 'LGPD_DATA_CATEGORY'
  AND tr.DOMAIN = 'TABLE'
WHERE t.DELETED IS NULL
  AND t.TABLE_SCHEMA != 'INFORMATION_SCHEMA'
ORDER BY STATUS_CONFORMIDADE DESC, t.TABLE_CATALOG, t.TABLE_SCHEMA;


-- -------------------------------------------------------------
-- 9.3: Colunas com e sem masking policies
-- -------------------------------------------------------------

SELECT
  pr.REF_DATABASE_NAME AS DATABASE_NAME,
  pr.REF_SCHEMA_NAME   AS SCHEMA_NAME,
  pr.REF_ENTITY_NAME   AS TABLE_NAME,
  pr.REF_COLUMN_NAME   AS COLUMN_NAME,
  pr.POLICY_NAME,
  pr.POLICY_STATUS,
  COALESCE(pr.TAG_NAME, 'DIRETA') AS APLICACAO
FROM SNOWFLAKE.ACCOUNT_USAGE.POLICY_REFERENCES pr
WHERE pr.POLICY_KIND = 'MASKING_POLICY'
ORDER BY pr.REF_DATABASE_NAME, pr.REF_ENTITY_NAME, pr.REF_COLUMN_NAME;


-- -------------------------------------------------------------
-- 9.3b: Inventario de Projection Policies
-- -------------------------------------------------------------

SELECT
  pp.POLICY_NAME,
  pp.POLICY_CATALOG AS POLICY_DATABASE,
  pp.POLICY_SCHEMA,
  pp.CREATED,
  pp.POLICY_COMMENT
FROM SNOWFLAKE.ACCOUNT_USAGE.PROJECTION_POLICIES pp
WHERE pp.DELETED IS NULL
ORDER BY pp.CREATED;

-- Colunas protegidas por projection policies na tabela CLIENTES
SELECT POLICY_NAME, POLICY_KIND, REF_COLUMN_NAME, POLICY_STATUS
FROM TABLE(EMPRESA_DEMO.INFORMATION_SCHEMA.POLICY_REFERENCES(
  ref_entity_name => 'EMPRESA_DEMO.DADOS_CLIENTES.CLIENTES',
  ref_entity_domain => 'TABLE'
))
WHERE POLICY_KIND = 'PROJECTION_POLICY'
ORDER BY REF_COLUMN_NAME;


-- -------------------------------------------------------------
-- 9.4: Requisicoes DSAR pendentes (SLA 15 dias)
-- -------------------------------------------------------------

USE ROLE LGPD_DPO;

SELECT
  REQUEST_ID,
  REQUEST_TYPE,
  TITULAR_ID,
  REQUESTED_BY,
  REQUESTED_AT,
  STATUS,
  DATEDIFF('day', REQUESTED_AT, CURRENT_TIMESTAMP()) AS DIAS_ABERTO,
  CASE
    WHEN DATEDIFF('day', REQUESTED_AT, CURRENT_TIMESTAMP()) > 15
      THEN 'ATRASADO'
    WHEN DATEDIFF('day', REQUESTED_AT, CURRENT_TIMESTAMP()) > 10
      THEN 'ATENCAO'
    ELSE 'DENTRO DO PRAZO'
  END AS SLA_STATUS
FROM LGPD_GOVERNANCE.AUDIT.DSAR_LOG
WHERE STATUS = 'PENDENTE'
ORDER BY REQUESTED_AT ASC;


-- -------------------------------------------------------------
-- 9.5: Alerta para acessos anomalos (Art. 48 - Incidentes)
-- -------------------------------------------------------------

-- Pre-requisito: criar notification integration para email
USE ROLE ACCOUNTADMIN;
CREATE OR REPLACE NOTIFICATION INTEGRATION LGPD_NOTIFICATIONS
  TYPE = EMAIL
  ENABLED = TRUE
  ALLOWED_RECIPIENTS = ($LGPD_DPO_EMAIL);

USE ROLE LGPD_DPO;

CREATE OR REPLACE ALERT LGPD_GOVERNANCE.AUDIT.ALERT_MASS_DATA_ACCESS
  WAREHOUSE = LGPD_TRAINING_WH
  SCHEDULE = 'USING CRON 0 */6 * * * America/Sao_Paulo'
  IF (EXISTS (
    SELECT 1
    FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
    WHERE EXECUTION_STATUS = 'SUCCESS'
      AND ROWS_PRODUCED > 10000
      AND QUERY_START_TIME >= DATEADD('hour', -6, CURRENT_TIMESTAMP())
      AND (QUERY_TEXT ILIKE '%clientes%' OR QUERY_TEXT ILIKE '%dados_pessoais%')
  ))
  THEN
    CALL SYSTEM$SEND_EMAIL(
      'LGPD_NOTIFICATIONS',
      $LGPD_DPO_EMAIL,
      'ALERTA LGPD: Acesso massivo a dados pessoais detectado',
      'Uma consulta retornou mais de 10.000 registros de tabelas contendo dados pessoais nas ultimas 6 horas. Verifique o ACCESS_HISTORY para detalhes.'
    );

-- Ativar o alerta
ALTER ALERT LGPD_GOVERNANCE.AUDIT.ALERT_MASS_DATA_ACCESS RESUME;


-- =============================================================================
-- FIM DO TREINAMENTO
-- =============================================================================
-- Todos os 9 modulos foram validados e executados com sucesso.
-- Consulte o HTML (LGPD_SNOW.html) para detalhes conceituais de cada modulo.
-- =============================================================================
