-- Unificar os antigos status Resolvido/Concluido em Finalizado.
-- Execute somente apos conferir que estes sao os tres status desejados.
BEGIN;
ALTER TABLE public.chamados DROP CONSTRAINT IF EXISTS chamados_status_check;
UPDATE public.chamados SET status = 'Finalizado' WHERE status IN ('Resolvido','Concluido');
ALTER TABLE public.chamados ALTER COLUMN status SET DEFAULT 'Aguardando Amazon';
ALTER TABLE public.chamados ADD CONSTRAINT chamados_status_check CHECK (status IN ('Aguardando Amazon','Pendente Seller','Finalizado'));
COMMIT;
