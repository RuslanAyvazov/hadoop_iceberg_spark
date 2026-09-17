"use strict";

const state = {
  namespace: [],
  selectedVolume: null,
  selectedBucket: null,
  currentPath: null,
  selectedPath: null,
  files: [],
};

const elements = {
  clusterState: document.querySelector("#cluster-state"),
  currentPath: document.querySelector("#current-path"),
  refresh: document.querySelector("#refresh-button"),
  preview: document.querySelector("#preview-button"),
  volumeName: document.querySelector("#volume-name"),
  createVolume: document.querySelector("#create-volume"),
  namespaceTree: document.querySelector("#namespace-tree"),
  namespaceCounter: document.querySelector("#namespace-counter"),
  bucketForm: document.querySelector("#bucket-form"),
  bucketVolumeName: document.querySelector("#bucket-volume-name"),
  bucketName: document.querySelector("#bucket-name"),
  bucketLayout: document.querySelector("#bucket-layout"),
  closeBucketForm: document.querySelector("#close-bucket-form"),
  breadcrumbs: document.querySelector("#breadcrumbs"),
  fileList: document.querySelector("#file-list"),
  fileCounter: document.querySelector("#file-counter"),
  dataframePanel: document.querySelector(".dataframe-panel"),
  dataframeStage: document.querySelector("#dataframe-stage"),
  format: document.querySelector("#format-select"),
  limit: document.querySelector("#row-limit"),
  jobBar: document.querySelector("#job-bar"),
  sparkCommand: document.querySelector("#spark-command"),
  jobFormat: document.querySelector("#job-format"),
  jobColumns: document.querySelector("#job-columns"),
  jobTime: document.querySelector("#job-time"),
  toasts: document.querySelector("#toast-region"),
};

async function api(path, options = {}) {
  const response = await fetch(path, {
    ...options,
    headers: { "Content-Type": "application/json", ...(options.headers || {}) },
  });
  let payload;
  try {
    payload = await response.json();
  } catch {
    payload = { error: `Сервис вернул HTTP ${response.status}.` };
  }
  if (!response.ok) throw new Error(payload.error || `Ошибка HTTP ${response.status}`);
  return payload;
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function toast(message, kind = "success") {
  const item = document.createElement("div");
  item.className = `toast ${kind}`;
  item.textContent = message;
  elements.toasts.append(item);
  window.setTimeout(() => item.remove(), 5000);
}

function setClusterState(mode, text) {
  elements.clusterState.className = `cluster-state ${mode}`;
  elements.clusterState.querySelector(".state-copy").textContent = text;
}

function setBusy(button, busy, busyText) {
  if (!button.dataset.label) button.dataset.label = button.textContent.trim();
  button.disabled = busy;
  button.textContent = busy ? busyText : button.dataset.label;
}

function humanBytes(bytes) {
  if (bytes === 0) return "0 B";
  if (!Number.isFinite(bytes)) return "—";
  const units = ["B", "KB", "MB", "GB", "TB"];
  const index = Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), units.length - 1);
  return `${(bytes / 1024 ** index).toFixed(index ? 1 : 0)} ${units[index]}`;
}

function shortDate(iso) {
  const date = new Date(iso);
  if (Number.isNaN(date.valueOf())) return "—";
  return new Intl.DateTimeFormat("ru-RU", {
    day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit",
  }).format(date);
}

function fieldType(field) {
  const value = field.type ?? field.dataType;
  if (typeof value === "string") return value;
  if (value && value.type) return value.type;
  return "complex";
}

function cellValue(value) {
  if (value === null || value === undefined) return '<span class="null-value">NULL</span>';
  if (typeof value === "object") return escapeHtml(JSON.stringify(value));
  return escapeHtml(value);
}

async function loadNamespace({ preserveSelection = true } = {}) {
  setClusterState("", "Чтение пространства Ozone");
  try {
    const result = await api("/api/namespace");
    state.namespace = result.volumes || [];
    if (preserveSelection && state.selectedVolume) {
      const volume = state.namespace.find((item) => item.name === state.selectedVolume);
      if (!volume || !volume.buckets.some((item) => item.name === state.selectedBucket)) {
        state.selectedVolume = null;
        state.selectedBucket = null;
      }
    }
    renderNamespace();
    setClusterState("online", "Ozone и Spark готовы");
  } catch (error) {
    state.namespace = [];
    renderNamespace(error.message);
    setClusterState("offline", "Нет связи с Ozone");
    toast(error.message, "error");
  }
}

function renderNamespace(errorMessage = "") {
  const bucketCount = state.namespace.reduce((sum, volume) => sum + volume.buckets.length, 0);
  elements.namespaceCounter.textContent = `${state.namespace.length} V / ${bucketCount} B`;
  if (errorMessage) {
    elements.namespaceTree.innerHTML = `<div class="empty-state compact"><p>${escapeHtml(errorMessage)}</p></div>`;
    return;
  }
  if (!state.namespace.length) {
    elements.namespaceTree.innerHTML = '<div class="empty-state compact"><span class="empty-glyph">Ø</span><p>Volume пока нет. Создайте первый выше.</p></div>';
    return;
  }
  elements.namespaceTree.innerHTML = state.namespace.map((volume) => `
    <div class="tree-volume">
      <div class="volume-line">
        <span class="tree-icon">VOL</span>
        <span class="tree-name">${escapeHtml(volume.name)}</span>
        <span class="tree-count">${volume.buckets.length}</span>
      </div>
      <div class="bucket-list">
        ${volume.buckets.map((bucket) => `
          <button class="bucket-line ${state.selectedVolume === volume.name && state.selectedBucket === bucket.name ? "selected" : ""}"
                  type="button" data-volume="${escapeHtml(volume.name)}" data-bucket="${escapeHtml(bucket.name)}" data-path="${escapeHtml(bucket.path)}">
            <span class="tree-name">${escapeHtml(bucket.name)}</span>
            <span class="layout-tag">${bucket.layout === "FILE_SYSTEM_OPTIMIZED" ? "FSO" : "OBS"}</span>
          </button>`).join("")}
        <button class="bucket-line add-bucket" type="button" data-add-bucket="${escapeHtml(volume.name)}">+ bucket</button>
      </div>
    </div>`).join("");
}

async function selectBucket(volume, bucket, path) {
  state.selectedVolume = volume;
  state.selectedBucket = bucket;
  state.currentPath = path;
  state.selectedPath = path;
  elements.currentPath.textContent = path;
  elements.preview.disabled = false;
  renderNamespace();
  await loadFiles(path);
}

async function loadFiles(path) {
  state.currentPath = path;
  state.selectedPath = path;
  elements.currentPath.textContent = path;
  renderBreadcrumbs(path);
  elements.fileCounter.textContent = "…";
  elements.fileList.innerHTML = '<div class="skeleton-line wide"></div><div class="skeleton-line"></div><div class="skeleton-line short"></div>';
  try {
    const result = await api(`/api/files?path=${encodeURIComponent(path)}`);
    state.files = result.files || [];
    renderFiles();
  } catch (error) {
    state.files = [];
    elements.fileCounter.textContent = "ERR";
    elements.fileList.innerHTML = `<div class="empty-state compact"><p>${escapeHtml(error.message)}</p></div>`;
    toast(error.message, "error");
  }
}

function renderBreadcrumbs(path) {
  const parts = path.replace("ofs://om/", "").split("/").filter(Boolean);
  elements.breadcrumbs.innerHTML = '<span class="crumb-separator">ofs://om</span>' + parts.map((part, index) => {
    const target = `ofs://om/${parts.slice(0, index + 1).join("/")}`;
    if (index === 0) return `<span class="crumb-separator">/</span><span class="crumb">${escapeHtml(part)}</span>`;
    return `<span class="crumb-separator">/</span><button type="button" class="crumb" data-path="${escapeHtml(target)}">${escapeHtml(part)}</button>`;
  }).join("");
}

function renderFiles() {
  elements.fileCounter.textContent = String(state.files.length);
  if (!state.files.length) {
    elements.fileList.innerHTML = '<div class="empty-state compact"><span class="empty-glyph">∅</span><p>В этом пути пока нет файлов.</p></div>';
    return;
  }
  elements.fileList.innerHTML = state.files.map((file) => `
    <button type="button" class="file-row ${state.selectedPath === file.path ? "selected" : ""}"
            data-path="${escapeHtml(file.path)}" data-directory="${file.directory}">
      <span class="file-name"><span class="file-kind">${file.directory ? "DIR" : "DOC"}</span><span>${escapeHtml(file.name)}</span></span>
      <span class="file-size">${file.directory ? "—" : humanBytes(file.size)}</span>
      <span class="file-date">${shortDate(file.modified)}</span>
    </button>`).join("");
}

async function createVolume() {
  const name = elements.volumeName.value.trim();
  if (!name) return toast("Введите имя volume.", "error");
  setBusy(elements.createVolume, true, "…");
  try {
    const result = await api("/api/volumes", { method: "POST", body: JSON.stringify({ name }) });
    elements.volumeName.value = "";
    toast(`Volume ${result.name} создан.`);
    await loadNamespace({ preserveSelection: true });
  } catch (error) {
    toast(error.message, "error");
  } finally {
    setBusy(elements.createVolume, false, "");
  }
}

function openBucketForm(volume) {
  state.selectedVolume = volume;
  elements.bucketVolumeName.textContent = volume;
  elements.bucketForm.hidden = false;
  elements.bucketName.focus();
}

async function createBucket(event) {
  event.preventDefault();
  const submit = elements.bucketForm.querySelector('button[type="submit"]');
  setBusy(submit, true, "Создание…");
  try {
    const result = await api("/api/buckets", {
      method: "POST",
      body: JSON.stringify({ volume: state.selectedVolume, name: elements.bucketName.value, layout: elements.bucketLayout.value }),
    });
    elements.bucketName.value = "";
    elements.bucketForm.hidden = true;
    toast(`Bucket ${result.volume}/${result.name} создан.`);
    await loadNamespace({ preserveSelection: false });
    await selectBucket(result.volume, result.name, result.path);
  } catch (error) {
    toast(error.message, "error");
  } finally {
    setBusy(submit, false, "");
  }
}

function showLoading() {
  elements.dataframePanel.classList.remove("trace-active");
  elements.jobBar.hidden = true;
  elements.dataframeStage.innerHTML = `
    <div class="loading-state" role="status">
      <div>SPARK ВЫПОЛНЯЕТ ЧТЕНИЕ DATAFRAME</div>
      <div class="loading-line" aria-hidden="true"></div>
      <code>${escapeHtml(state.selectedPath)}</code>
    </div>`;
}

async function preview() {
  if (!state.selectedPath) return;
  showLoading();
  elements.preview.disabled = true;
  try {
    const result = await api("/api/preview", {
      method: "POST",
      body: JSON.stringify({ path: state.selectedPath, format: elements.format.value, limit: Number(elements.limit.value) }),
    });
    renderDataframe(result);
  } catch (error) {
    elements.dataframeStage.innerHTML = `<div class="empty-state dataframe-empty"><span class="empty-glyph">!</span><h3>Не удалось прочитать DataFrame</h3><p>${escapeHtml(error.message)}</p></div>`;
    toast(error.message, "error");
  } finally {
    elements.preview.disabled = false;
  }
}

function renderDataframe(result) {
  const headers = result.columns.map((column) => `<th title="${escapeHtml(column)}">${escapeHtml(column)}</th>`).join("");
  const rows = result.rows.map((row, index) => `<tr><td>${index + 1}</td>${result.columns.map((column) => `<td title="${escapeHtml(typeof row[column] === "object" ? JSON.stringify(row[column]) : row[column] ?? "NULL")}">${cellValue(row[column])}</td>`).join("")}</tr>`).join("");
  const schema = result.schema.map((field) => `<div class="schema-field ${field.nullable ? "nullable" : ""}"><strong title="${escapeHtml(field.name)}">${escapeHtml(field.name)}</strong><span>${escapeHtml(fieldType(field))}</span></div>`).join("");

  elements.dataframeStage.innerHTML = `
    <div class="schema-strip">
      <div class="schema-title">SCHEMA</div>
      <div class="schema-fields">${schema}</div>
    </div>
    <div class="table-wrap">
      <table class="data-table">
        <thead><tr><th>#</th>${headers}</tr></thead>
        <tbody>${rows || `<tr><td>—</td><td colspan="${Math.max(1, result.columns.length)}">DataFrame не содержит строк</td></tr>`}</tbody>
      </table>
    </div>`;
  elements.sparkCommand.textContent = result.command;
  elements.sparkCommand.title = result.command;
  elements.jobFormat.textContent = result.format;
  elements.jobColumns.textContent = `${result.columns.length} колонок`;
  elements.jobTime.textContent = `${result.elapsedMs} мс${result.truncated ? " · есть ещё строки" : ""}`;
  elements.jobBar.hidden = false;
  elements.dataframePanel.classList.add("trace-active");
}

elements.namespaceTree.addEventListener("click", (event) => {
  const bucket = event.target.closest("[data-bucket]");
  if (bucket) return void selectBucket(bucket.dataset.volume, bucket.dataset.bucket, bucket.dataset.path);
  const add = event.target.closest("[data-add-bucket]");
  if (add) openBucketForm(add.dataset.addBucket);
});

elements.fileList.addEventListener("click", (event) => {
  const row = event.target.closest("[data-path]");
  if (!row) return;
  state.selectedPath = row.dataset.path;
  elements.currentPath.textContent = state.selectedPath;
  elements.preview.disabled = false;
  if (row.dataset.directory === "true") loadFiles(state.selectedPath);
  else renderFiles();
});

elements.fileList.addEventListener("dblclick", (event) => {
  const row = event.target.closest('[data-directory="false"]');
  if (row) preview();
});

elements.breadcrumbs.addEventListener("click", (event) => {
  const crumb = event.target.closest("[data-path]");
  if (crumb) loadFiles(crumb.dataset.path);
});

elements.createVolume.addEventListener("click", createVolume);
elements.volumeName.addEventListener("keydown", (event) => { if (event.key === "Enter") createVolume(); });
elements.bucketForm.addEventListener("submit", createBucket);
elements.closeBucketForm.addEventListener("click", () => { elements.bucketForm.hidden = true; });
elements.preview.addEventListener("click", preview);
elements.refresh.addEventListener("click", async () => {
  await loadNamespace();
  if (state.currentPath) await loadFiles(state.currentPath);
});

loadNamespace();
