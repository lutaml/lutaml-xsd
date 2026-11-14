<template>
  <div class="playground-view">
    <div class="playground-header">
      <h1>Live validation playground</h1>
      <p class="playground-sub">
        Paste or upload an XML instance and validate it against this
        package's schemas.
      </p>
    </div>

    <div class="playground-body">
      <div class="editor-pane">
        <div class="editor-toolbar">
          <span class="pane-label">Instance</span>
          <label class="btn btn-secondary upload-btn">
            Upload…
            <input type="file" accept=".xml,text/xml" @change="onUpload" />
          </label>
          <button
            class="btn btn-primary validate-btn"
            :disabled="validating || !instance.trim()"
            @click="validate"
          >
            {{ validating ? 'Validating…' : 'Validate' }}
          </button>
        </div>
        <textarea
          v-model="instance"
          class="instance-editor"
          spellcheck="false"
          placeholder="<doc>…</doc>"
        ></textarea>

        <div v-if="treeNodes.length" class="tree-pane">
          <span class="pane-label">Instance tree</span>
          <ul class="tree-list">
            <li
              v-for="node in flattenedTree"
              :key="node.path"
              class="tree-node"
              :style="{ marginLeft: `${node.depth * 16}px` }"
              :class="{ 'node-invalid': node.invalid }"
              :title="node.invalid ? 'A finding references this element' : ''"
            >
              <span class="tree-marker">{{ node.invalid ? '✖' : '·' }}</span>
              <span class="tree-name">{{ node.name }}</span>
            </li>
          </ul>
        </div>
      </div>

      <div class="result-pane">
        <div v-if="error" class="result-banner banner-error">{{ error }}</div>
        <template v-if="result">
          <div
            class="result-banner"
            :class="result.valid ? 'banner-valid' : 'banner-invalid'"
          >
            {{ result.valid ? 'The instance is VALID.' : 'The instance is INVALID.' }}
          </div>
          <ul v-if="findings.length" class="findings-list">
            <li
              v-for="(finding, index) in findings"
              :key="index"
              class="finding"
              :class="{ 'finding-clickable': !!finding.link }"
              :title="finding.link ? 'Open the schema component' : ''"
              @click="finding.link && openComponent(finding.link)"
            >
              <span class="finding-severity" :class="`severity-${finding.kind}`">
                {{ finding.kind }}
              </span>
              <span class="finding-code">{{ finding.code }}</span>
              <span v-if="finding.location" class="finding-location">
                {{ finding.location }}
              </span>
              <p class="finding-message">{{ finding.message }}</p>
              <span v-if="finding.link" class="finding-link-hint">
                → {{ finding.link.name }}
              </span>
            </li>
          </ul>
          <p v-else class="findings-empty">
            No findings reported.
          </p>
        </template>
        <p v-if="!result && !error" class="result-placeholder">
          Validate an instance to see findings here.
        </p>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { useRouter } from 'vue-router'
import { useSchemaStore } from '@/stores/schemaStore'
import { useUiStore } from '@/stores/uiStore'

interface Finding {
  code: string
  message: string
  severity?: string
  location?: string | null
  kind?: string
  link?: { schemaId: string; typeId: string; name: string } | null
}

interface ValidateResponse {
  valid: boolean
  errors: Finding[]
  warnings: Finding[]
}

interface TreeNode {
  name: string
  path: string
  depth: number
  invalid: boolean
}

const router = useRouter()
const schemaStore = useSchemaStore()
const uiStore = useUiStore()

const instance = ref('')
const validating = ref(false)
const result = ref<ValidateResponse | null>(null)
const error = ref('')

const findings = computed(() => {
  if (!result.value) return []
  return [
    ...(result.value.errors || []).map((f) => ({ ...f, kind: 'error' })),
    ...(result.value.warnings || []).map((f) => ({ ...f, kind: 'warning' })),
  ].map((f) => ({ ...f, link: componentLink(f) }))
})

const treeNodes = computed<TreeNode[]>(() => {
  if (!result.value) return []
  try {
    const doc = new DOMParser().parseFromString(instance.value, 'application/xml')
    if (doc.querySelector('parsererror')) return []
    const out: TreeNode[] = []
    const invalidNames = findingNames()
    walk(doc.documentElement, '', 0, invalidNames, out)
    return out
  } catch {
    return []
  }
})

const flattenedTree = computed(() => treeNodes.value)

function walk(
  element: Element,
  parentPath: string,
  depth: number,
  invalidNames: Set<string>,
  out: TreeNode[]
) {
  const path = `${parentPath}/${element.localName}`
  out.push({
    name: element.localName,
    path,
    depth,
    invalid: invalidNames.has(element.localName),
  })
  for (const child of Array.from(element.children)) {
    walk(child, path, depth + 1, invalidNames, out)
  }
}

function findingNames(): Set<string> {
  const names = new Set<string>()
  for (const finding of findings.value) {
    for (const source of [finding.location, finding.message]) {
      if (!source) continue
      for (const match of source.matchAll(/'([^']+)'|\/([A-Za-z_][\w.-]*)/g)) {
        const name = match[1] || match[2]
        if (name && !/^\d/.test(name)) names.add(name)
      }
    }
  }
  return names
}

// A finding links to the schema component whose name appears in its
// location or message — first match across every loaded schema's
// elements, types, attributes, groups, and attribute groups.
function componentLink(finding: Finding):
  { schemaId: string; typeId: string; name: string } | null {
  const names = new Set<string>()
  for (const source of [finding.location, finding.message]) {
    if (!source) continue
    for (const match of source.matchAll(/'([^']+)'|\/([A-Za-z_][\w.-]*)/g)) {
      const name = match[1] || match[2]
      if (name && !/^\d/.test(name)) names.add(name)
    }
  }
  for (const schema of schemaStore.schemas) {
    const buckets = [
      ...(schema.elements ?? []),
      ...(schema.complex_types ?? []),
      ...(schema.simple_types ?? []),
      ...(schema.attributes ?? []),
      ...(schema.groups ?? []),
      ...(schema.attribute_groups ?? []),
    ]
    for (const component of buckets) {
      const componentName = (component as { name?: string }).name
      if (componentName && names.has(componentName)) {
        return {
          schemaId: schema.id,
          typeId: component.id,
          name: componentName,
        }
      }
    }
  }
  return null
}

function openComponent(link: { schemaId: string; typeId: string; name: string }) {
  schemaStore.selectSchema(link.schemaId)
  schemaStore.selectType(link.typeId)
  uiStore.openDetailPanel()
  router.push(`/schema/${link.schemaId}`)
}

function onUpload(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  if (!file) return
  file.text().then((text) => {
    instance.value = text
  })
}

async function validate() {
  validating.value = true
  error.value = ''
  try {
    const res = await fetch('/api/validate', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ instance: instance.value }),
    })
    if (!res.ok) {
      const body = await res.json().catch(() => null)
      error.value = body?.errors?.[0]?.message || `Validation request failed (${res.status})`
      result.value = null
      return
    }
    result.value = await res.json()
  } catch (err) {
    error.value = `Could not reach the validation API: ${String(err)}`
    result.value = null
  } finally {
    validating.value = false
  }
}
</script>

<style scoped>
.playground-view {
  display: flex;
  flex-direction: column;
  height: 100%;
  padding: var(--space-4);
  gap: var(--space-4);
  overflow: auto;
}

.playground-header h1 {
  margin: 0;
  font-size: var(--text-lg);
}

.playground-sub {
  margin: var(--space-1) 0 0;
  color: var(--text-muted);
  font-size: var(--text-sm);
}

.playground-body {
  display: grid;
  grid-template-columns: minmax(280px, 1fr) minmax(280px, 1fr);
  gap: var(--space-4);
  flex: 1;
  min-height: 320px;
}

.editor-pane {
  display: flex;
  flex-direction: column;
  gap: var(--space-2);
}

.editor-toolbar {
  display: flex;
  align-items: center;
  gap: var(--space-2);
}

.pane-label {
  flex: 1;
  font-size: var(--text-sm);
  font-weight: 600;
  color: var(--text-secondary);
}

.upload-btn input {
  display: none;
}

.instance-editor {
  flex: 1;
  min-height: 200px;
  padding: var(--space-3);
  background: var(--bg-secondary);
  color: var(--text-primary);
  border: 1px solid var(--border-light);
  border-radius: var(--radius-md);
  font-family: var(--font-mono);
  font-size: var(--text-sm);
  resize: vertical;
}

.tree-pane {
  display: flex;
  flex-direction: column;
  max-height: 220px;
  overflow: auto;
  background: var(--bg-secondary);
  border: 1px solid var(--border-light);
  border-radius: var(--radius-md);
  padding: var(--space-2);
}

.tree-list {
  list-style: none;
  margin: var(--space-1) 0 0;
  padding: 0;
  font-family: var(--font-mono);
  font-size: var(--text-xs);
}

.tree-node {
  padding: 1px 0;
  color: var(--text-secondary);
}

.tree-node.node-invalid {
  color: #dc3545;
  font-weight: 600;
}

.tree-marker {
  margin-right: var(--space-1);
}

.result-pane {
  display: flex;
  flex-direction: column;
  gap: var(--space-2);
  min-width: 0;
}

.result-banner {
  padding: var(--space-3);
  border-radius: var(--radius-md);
  font-weight: 600;
  font-size: var(--text-sm);
}

.banner-valid {
  background: var(--color-success-alpha, rgba(40, 167, 69, 0.15));
  color: var(--color-success, #28a745);
}

.banner-invalid,
.banner-error {
  background: var(--color-danger-alpha, rgba(220, 53, 69, 0.15));
  color: var(--color-danger, #dc3545);
}

.findings-list {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: var(--space-2);
  overflow: auto;
}

.finding {
  padding: var(--space-3);
  background: var(--bg-secondary);
  border: 1px solid var(--border-light);
  border-radius: var(--radius-md);
  font-size: var(--text-sm);
}

.finding-clickable {
  cursor: pointer;
}

.finding-clickable:hover {
  border-color: var(--border-medium);
  background: var(--bg-hover);
}

.finding-severity {
  display: inline-block;
  padding: 2px 8px;
  border-radius: var(--radius-sm);
  font-size: var(--text-xs);
  font-weight: 600;
  text-transform: uppercase;
  margin-right: var(--space-2);
}

.severity-error {
  background: rgba(220, 53, 69, 0.15);
  color: #dc3545;
}

.severity-warning {
  background: rgba(255, 193, 7, 0.18);
  color: #b58900;
}

.finding-code {
  font-family: var(--font-mono);
  color: var(--text-secondary);
}

.finding-location {
  display: inline-block;
  margin-left: var(--space-2);
  font-family: var(--font-mono);
  font-size: var(--text-xs);
  color: var(--text-muted);
}

.finding-message {
  margin: var(--space-2) 0 0;
  color: var(--text-primary);
}

.finding-link-hint {
  display: inline-block;
  margin-left: var(--space-2);
  color: var(--color-accent, #4a90d9);
  font-size: var(--text-xs);
}

.findings-empty,
.result-placeholder {
  color: var(--text-muted);
  font-size: var(--text-sm);
  padding: var(--space-3);
}
</style>
