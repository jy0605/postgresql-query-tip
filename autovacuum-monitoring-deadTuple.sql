-- 2022.3.25 dead tuple monitoring and set autovacuum 

-- dead tuple monitoring
SELECT relname, n_dead_tup, n_live_tup, (n_dead_tup / n_live_tup) AS DeadTuplesRatio, last_vacuum, last_autovacuum 
FROM pg_catalog.pg_stat_all_tables 
WHERE relname = 'rainfall'  -- 본인의 테이블명
ORDER BY n_dead_tup DESC;
-- 10분당 tuple이 얼마나 증가하는가? => 202203251750 adj 수신 이후 tuple 수 : 1,218,426 / dead_tuple : 6,487,547
-- 202203251800 mpl 수신 이후 tuple 수 : 1,415,768 / dead_tuple : 6,487,547


-- table별로 autovacuum설정하기
ALTER TABLE rainfall SET (autovacuum_vacuum_scale_factor = 0.0); -- dead tuple rate
ALTER TABLE rainfall SET (autovacuum_vacuum_threshold = 100000); -- dead tuple's number
ALTER TABLE rainfall SET (autovacuum_vacuum_cost_limit = 1000); -- -1일경우 vacuum_cost_limit을 참조함. 기존값은 200이었으므로 이럴경우 기존보다 약 5배 많은 vacuuming을 한번에 처리하게 됨
ALTER TABLE rainfall SET (autovacuum_enabled = true); -- autovacuum 설정을 enable로

-- track_counts=on인 경우 tuple count를 track하는 것임
select name, setting from pg_settings where name='track_counts';
-- 해당 테이블에 대한 relation option을 확인할 수 있음
select reloptions from pg_class where relname='rainfall';
-- autovacuum에 대한 설정값을 일괄 확인할 수 있음
select * from pg_settings where category like '%vacuum%';

-- 현재 autovacuum이 돌아가는중일까? stat_activity를 확인해보기
select * from pg_catalog.pg_stat_activity where query like 'autovacuum:%';

-- Disk정리를 위해서는 정기적으로 수동 vacuum도 필요할 것임. autovacuum은 디스크 용량 확보에 적합하지 않음

-- memo : 현재상황이.. deadtuple 수는 줄지 않았는데, query status를 확인해보니 상태는 53분에 변한것으로 보임. 쿼리start가 35분이 아니라 53분임. tuple은 줄지 않았는데..
-- xmln row 등 뭔가 정보가 보이긴 하는데(뭐가 붙잡고 있어서 삭제가 안되는, 삭제할 수 없는 dead row일 수도 있음) -> https://www.cybertec-postgresql.com/en/reasons-why-vacuum-wont-remove-dead-rows/
-- 일단 지켜봐야할 듯
-- 20:35 확인해보니 dead tuple=0, last_autovacuum 은 2022-03-25 20:12:45.478 +0900,vacuum count=11,303, autovacuumcount= 128

-- 아래는 table status(last vacuum 등 확인할 수 있는 query)
SELECT
  schemaname, relname,
  last_vacuum, last_autovacuum,
  vacuum_count, autovacuum_count  -- not available on 9.0 and earlier
FROM pg_stat_user_tables;

select count(*) from rainfall;
select adj_time from rainfall order by adj_time limit 1;


-- 열린 트랜잭션이 얼마나 오래 실행되는지 보여줌(xact_start : 트랜잭션 시작시간)
select pid, current_timestamp-xact_start as xact_runtime, query from pg_stat_activity order by xact_start;
