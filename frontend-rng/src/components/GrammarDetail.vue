<template>
  <div v-if="grammar" class="grammar-detail">
    <div class="detail-header">
      <h2 class="detail-title">{{ grammar.name }}</h2>
      <div class="detail-file">{{ grammar.file_path }}</div>
    </div>

    <section v-if="grammar.start_refs.length > 0" class="detail-section">
      <h3 class="section-title">Start</h3>
      <div class="start-refs">
        <span v-for="ref in grammar.start_refs" :key="ref" class="ref-badge start-ref">
          {{ ref }}
        </span>
      </div>
    </section>

    <section v-for="group in grammar.define_groups" :key="group.source_href || 'main'" class="detail-section">
      <h3 class="section-title">
        <span v-if="group.source === 'main'">
          Defines
        </span>
        <span v-else class="include-label">
          <span class="include-icon">&#x2192;</span>
          Include: <span class="include-href">{{ group.source_href }}</span>
        </span>
        <span class="section-count">{{ group.defines.length }}</span>
      </h3>
      <ul class="define-list">
        <li
          v-for="define in group.defines"
          :key="define.name"
          class="define-item"
        >
          <div
            class="define-header"
            @click="store.toggleDefine(define.name)"
          >
            <span class="define-expand">{{ store.isDefineExpanded(define.name) ? '▼' : '▶' }}</span>
            <span class="define-name">{{ define.name }}</span>
            <span v-if="define.combine" class="define-combine">combine={{ define.combine }}</span>
            <span class="define-type-badge">{{ define.content_type }}</span>
          </div>
          <div v-if="store.isDefineExpanded(define.name)" class="define-detail">
            <div v-if="define.documentation" class="define-doc">{{ define.documentation }}</div>
            <div v-if="define.child_elements.length > 0" class="define-children">
              <span class="children-label">Elements:</span>
              <span v-for="elem in define.child_elements" :key="elem" class="child-badge element-badge">
                {{ elem }}
              </span>
            </div>
            <div v-if="define.child_attributes.length > 0" class="define-refs-table">
              <span class="children-label">Attributes:</span>
              <table class="ref-table">
                <thead>
                  <tr>
                    <th>Name</th>
                    <th>Context</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="attr in define.child_attributes" :key="attr.name">
                    <td class="attr-name">@{{ attr.name }}</td>
                    <td>
                      <span v-if="attr.context" class="context-badge">{{ attr.context }}</span>
                      <span v-else class="context-empty">-</span>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
            <div v-if="define.child_refs.length > 0" class="define-refs-table">
              <span class="children-label">Refs:</span>
              <table class="ref-table">
                <thead>
                  <tr>
                    <th>Name</th>
                    <th>Context</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="ref in define.child_refs" :key="ref.name">
                    <td class="ref-name">{{ ref.name }}</td>
                    <td>
                      <span v-if="ref.context" class="context-badge">{{ ref.context }}</span>
                      <span v-else class="context-empty">-</span>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
            <div v-if="define.child_values.length > 0" class="define-refs-table">
              <span class="children-label">Values:</span>
              <table class="ref-table">
                <thead>
                  <tr>
                    <th>Value</th>
                    <th>Type</th>
                    <th>Context</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="val in define.child_values" :key="val.value">
                    <td class="value-name">{{ val.value }}</td>
                    <td class="value-type">{{ val.type || '-' }}</td>
                    <td>
                      <span v-if="val.context" class="context-badge">{{ val.context }}</span>
                      <span v-else class="context-empty">-</span>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
            <div v-if="define.child_data.length > 0" class="define-refs-table">
              <span class="children-label">Data:</span>
              <table class="ref-table">
                <thead>
                  <tr>
                    <th>Type</th>
                    <th>Context</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="dat in define.child_data" :key="dat.type">
                    <td class="data-name">{{ dat.type }}</td>
                    <td>
                      <span v-if="dat.context" class="context-badge">{{ dat.context }}</span>
                      <span v-else class="context-empty">-</span>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </li>
      </ul>
    </section>

  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useGrammarStore } from '@/stores/grammarStore'

const store = useGrammarStore()
const grammar = computed(() => store.selectedGrammar)
</script>

<style scoped>
.grammar-detail {
  max-width: 900px;
}

.detail-header {
  margin-bottom: 24px;
}

.detail-title {
  font-size: 24px;
  font-weight: 600;
  color: var(--text-primary);
  margin: 0 0 4px 0;
}

.detail-file {
  font-size: 13px;
  color: var(--text-muted);
  font-family: var(--font-mono);
}

.detail-section {
  margin-bottom: 24px;
}

.section-title {
  font-size: 13px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--text-muted);
  margin: 0 0 12px 0;
  display: flex;
  align-items: center;
  gap: 8px;
}

.section-count {
  font-size: 11px;
  font-weight: 400;
  background: var(--bg-badge);
  padding: 1px 6px;
  border-radius: 8px;
}

.include-label {
  display: flex;
  align-items: center;
  gap: 4px;
}

.include-icon {
  color: var(--color-primary);
  font-size: 14px;
}

.include-href {
  font-family: var(--font-mono);
  font-size: 12px;
  color: var(--color-primary);
  background: var(--badge-include-bg);
  padding: 1px 6px;
  border-radius: 4px;
}

.start-refs {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.ref-badge {
  font-size: 12px;
  font-family: var(--font-mono);
  padding: 3px 8px;
  border-radius: 4px;
  background: var(--badge-ref-bg);
  color: var(--badge-ref);
}

.start-ref {
  background: var(--badge-start-bg);
  color: var(--badge-start);
  font-weight: 500;
}

.define-list {
  list-style: none;
  margin: 0;
  padding: 0;
  border: 1px solid var(--border-color);
  border-radius: 8px;
  overflow: hidden;
}

.define-item {
  border-bottom: 1px solid var(--border-color);
}

.define-item:last-child {
  border-bottom: none;
}

.define-header {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 10px 12px;
  cursor: pointer;
  transition: background 0.15s;
}

.define-header:hover {
  background: var(--bg-hover);
}

.define-expand {
  font-size: 10px;
  color: var(--text-muted);
  width: 14px;
  text-align: center;
}

.define-name {
  font-size: 14px;
  font-weight: 500;
  font-family: var(--font-mono);
  color: var(--text-primary);
  flex: 1;
}

.define-combine {
  font-size: 11px;
  color: var(--text-muted);
  font-family: var(--font-mono);
}

.define-type-badge {
  font-size: 11px;
  padding: 1px 6px;
  border-radius: 4px;
  background: var(--badge-type-bg);
  color: var(--badge-type);
}

.define-detail {
  padding: 8px 12px 12px 34px;
  border-top: 1px solid var(--border-light);
  background: var(--bg-primary);
}

.define-doc {
  font-size: 13px;
  color: var(--text-secondary);
  margin-bottom: 8px;
  font-style: italic;
}

.define-children {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 6px;
  margin-bottom: 6px;
}

.children-label {
  font-size: 11px;
  font-weight: 600;
  color: var(--text-muted);
  text-transform: uppercase;
  letter-spacing: 0.03em;
}

.child-badge {
  font-size: 12px;
  font-family: var(--font-mono);
  padding: 2px 6px;
  border-radius: 3px;
}

.element-badge {
  background: var(--badge-element-bg);
  color: var(--badge-element);
}

.attribute-badge {
  background: var(--badge-type-bg);
  color: var(--badge-type);
}

.ref-badge {
  background: var(--badge-ref-bg);
  color: var(--badge-ref);
}

.refs-list {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.define-refs-table {
  margin-bottom: 6px;
}

.ref-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 12px;
  margin-top: 4px;
}

.ref-table th {
  text-align: left;
  font-size: 11px;
  font-weight: 600;
  color: var(--text-muted);
  text-transform: uppercase;
  letter-spacing: 0.03em;
  padding: 4px 8px;
  border-bottom: 1px solid var(--border-color);
}

.ref-table td {
  padding: 4px 8px;
  border-bottom: 1px solid var(--border-light);
}

.ref-table tr:last-child td {
  border-bottom: none;
}

.ref-name {
  font-family: var(--font-mono);
  color: var(--badge-ref);
}

.attr-name {
  font-family: var(--font-mono);
  color: var(--badge-type);
}

.value-name {
  font-family: var(--font-mono);
  color: var(--badge-start);
}

.value-type {
  font-family: var(--font-mono);
  color: var(--text-muted);
  font-size: 11px;
}

.data-name {
  font-family: var(--font-mono);
  color: var(--badge-element);
}

.context-badge {
  font-size: 11px;
  padding: 1px 6px;
  border-radius: 4px;
  background: var(--badge-include-bg);
  color: var(--color-primary);
}

.context-empty {
  color: var(--text-muted);
}
</style>
