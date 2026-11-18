/**
 * Seller Pro — integração Google Forms / planilha de respostas -> Supabase de TESTES.
 * Colar na planilha vinculada ao Formulário: Extensões > Apps Script.
 * Configurar em Propriedades do script (NÃO colar segredos neste código):
 *   WEBHOOK_URL = https://qpczaqrnxjncetotuhwl.supabase.co/functions/v1/receber-formulario
 *   FORMS_WEBHOOK_SECRET = mesmo valor salvo no Supabase Edge Functions > Secrets
 *   SHEETS_TO_SYNC = Respostas ao formulário 1  (opcional, confirme o nome da aba)
 * No formulário NOVO: instalarGatilho(). No ANTIGO: importarHistorico() manualmente.
 */

var SELLERPRO_FORM_ANTIGO_ID = '1bQZRKsvnFfEjp4BRB4ZGX3nf1U8dTQvoZc9itxGb_Bo';
var SELLERPRO_FORM_NOVO_ID = '1ae0KuZWEpgdOmf3ycsRf6ADq5zB_RXcdVtRbP_WAMEQ';

function formProps_() {
  var p = PropertiesService.getScriptProperties();
  var url = p.getProperty('WEBHOOK_URL');
  var secret = p.getProperty('FORMS_WEBHOOK_SECRET');
  if (!url || !/^https:\/\/[^/]+\.supabase\.co\/functions\/v1\/receber-formulario$/.test(url)) {
    throw new Error('Configure WEBHOOK_URL da Edge Function de testes nas propriedades do script.');
  }
  if (!secret || secret.length < 32) throw new Error('Configure FORMS_WEBHOOK_SECRET (32+ caracteres).');
  var names = (p.getProperty('SHEETS_TO_SYNC') || 'Respostas ao formulário 1')
    .split(';').map(function(s) { return s.trim(); }).filter(Boolean);
  return { url: url, secret: secret, names: names, props: p };
}

function rowsToAnswers_(names, values) {
  var data = {};
  for (var i=0; i<names.length; i++) {
    var header = String(names[i] || '').trim();
    if (!header) continue;
    var value = values[i];
    if (Array.isArray(value)) value = value.join('; ');
    data[header] = String(value === null || value === undefined ? '' : value).trim();
  }
  return data;
}

function eventToPayload_(spreadsheetId, sheet, row, answers, enviadoEm) {
  return {
    origem_id: 'gsheet:' + spreadsheetId + ':' + sheet.getSheetId() + ':' + row,
    enviado_em: enviadoEm || null,
    respostas: answers
  };
}

function sendPayload_(payload, config) {
  var body = JSON.stringify(payload);
  var response = UrlFetchApp.fetch(config.url, {
    method: 'post',
    contentType: 'application/json',
    payload: body,
    headers: { 'x-forms-webhook-secret': config.secret },
    muteHttpExceptions: true,
    followRedirects: false
  });
  var code = response.getResponseCode();
  if (code < 200 || code >= 300) {
    throw new Error('Webhook respondeu HTTP ' + code + ' — ' + response.getContentText().slice(0, 300));
  }
  return response.getContentText();
}

/** Executada automaticamente pelo acionador DA PLANILHA > Ao enviar formulário. */
function onFormSubmit(e) {
  if (!e || !e.range || !e.namedValues) {
    throw new Error('Não execute onFormSubmit manualmente. Envie uma resposta pelo Google Forms.');
  }
  var cfg = formProps_();
  var sheet = e.range.getSheet();
  if (cfg.names.indexOf(sheet.getName()) === -1) return;
  var answers = {};
  Object.keys(e.namedValues).forEach(function(key) {
    var values = e.namedValues[key] || [];
    answers[key] = Array.isArray(values) ? values.join('; ') : String(values);
  });
  if (sheet.getParent().getId() !== SELLERPRO_FORM_NOVO_ID) {
    throw new Error('Envios automáticos só são permitidos na planilha NOVA.');
  }
  var timestamp = sheet.getRange(e.range.getRow(), 1).getValue();
  var enviadoEm = timestamp instanceof Date && !isNaN(timestamp.getTime()) ? timestamp.toISOString() : null;
  var entry = eventToPayload_(sheet.getParent().getId(), sheet, e.range.getRow(), answers, enviadoEm);
  sendPayload_(entry, cfg);
  Logger.log('Resposta encaminhada à triagem: linha ' + e.range.getRow());
}

/** Rodar UMA VEZ no Apps Script. Pede autorização à conta Google. */
function instalarGatilho() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  if (!ss) throw new Error('Abra o Apps Script dentro da planilha de respostas.');
  if (ss.getId() !== SELLERPRO_FORM_NOVO_ID) {
    throw new Error('Instale o acionador somente na planilha NOVA. O histórico é importado manualmente.');
  }
  var existing = ScriptApp.getProjectTriggers().some(function(t) {
    return t.getHandlerFunction() === 'onFormSubmit' &&
      t.getEventType() === ScriptApp.EventType.ON_FORM_SUBMIT;
  });
  if (existing) { Logger.log('Gatilho onFormSubmit já existe.'); return; }
  ScriptApp.newTrigger('onFormSubmit').forSpreadsheet(ss).onFormSubmit().create();
  Logger.log('Gatilho instalado para ' + ss.getName());
}

/**
 * Importação RETROATIVA opcional para testes — executar manualmente.
 * Envia no máximo 100 linhas por execução, sem duplicar por ID da planilha/aba/linha.
 * Execute novamente até o log informar "Concluído".
 * NÃO é executada automaticamente para evitar importar dados históricos sem revisão.
 */
function importarHistorico() {
  return importarRespostas_(SELLERPRO_FORM_ANTIGO_ID, 'HISTORICO');
}

/** Importação opcional das respostas já enviadas ao formulário novo (inclusive o teste). */
function importarTesteNovo() {
  return importarRespostas_(SELLERPRO_FORM_NOVO_ID, 'NOVO');
}

/** Execução manual, 100 linhas por vez. Não instala gatilhos. */
function importarRespostas_(expectedId, purpose) {
  var cfg = formProps_();
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  if (!ss || ss.getId() !== expectedId) throw new Error('Esta função não corresponde à planilha aberta.');
  var remaining = 100;
  var total = 0;
  var found = false;
  for (var s=0; s<cfg.names.length && remaining>0; s++) {
    var sheet = ss.getSheetByName(cfg.names[s]);
    if (!sheet) continue;
    found = true;
    if (sheet.getLastRow()<2) continue;
    var key = 'IMPORT_' + purpose + '_NEXT_ROW_' + sheet.getSheetId();
    var cursor = Math.max(2, Number(cfg.props.getProperty(key) || 2));
    var last = sheet.getLastRow();
    var headings = sheet.getRange(1,1,1,sheet.getLastColumn()).getDisplayValues()[0];
    while (cursor <= last && remaining > 0) {
      var count = Math.min(20,remaining,last-cursor+1);
      var range = sheet.getRange(cursor,1,count,sheet.getLastColumn());
      var rows = range.getDisplayValues();
      var dates = sheet.getRange(cursor,1,count,1).getValues();
      var entries = [];
      for (var i=0; i<rows.length; i++) {
        if (!rows[i].some(function(v){ return String(v || '').trim() !== ''; })) continue;
        var timestamp = dates[i][0];
        var sent = timestamp instanceof Date && !isNaN(timestamp.getTime()) ? timestamp.toISOString() : null;
        entries.push(eventToPayload_(ss.getId(),sheet,cursor+i,rowsToAnswers_(headings,rows[i]),sent));
      }
      // O cursor só avança após sucesso. IDs estáveis evitam duplicatas.
      if (entries.length) sendPayload_({ entradas: entries }, cfg);
      cursor += count;
      total += count;
      remaining -= count;
      cfg.props.setProperty(key,String(cursor));
    }
    Logger.log(sheet.getName() + ' → ' + (cursor>last ? 'Concluído' : 'Continuar na linha '+cursor));
  }
  if (!found) throw new Error('Aba não encontrada. Verifique SHEETS_TO_SYNC nas Propriedades do script.');
  Logger.log('Linhas percorridas nesta execução: ' + total);
}
