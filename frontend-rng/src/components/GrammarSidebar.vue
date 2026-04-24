<template>
  <aside class="sidebar">
    <div class="sidebar-header">
      <h2 class="sidebar-title">Grammar Groups</h2>
    </div>
    <nav class="sidebar-nav">
      <ul class="grammar-list">
        <li
          v-for="grammar in store.grammars"
          :key="grammar.id"
          class="grammar-item"
          :class="{ active: grammar.id === store.selectedGrammarId }"
          @click="store.selectGrammar(grammar.id)"
        >
          <div class="grammar-name">{{ grammar.name }}</div>
          <div class="grammar-meta">
            {{ grammar.define_groups.reduce((acc, g) => acc + g.defines.length, 0) }} define{{ grammar.define_groups.reduce((acc, g) => acc + g.defines.length, 0) !== 1 ? 's' : '' }}
          </div>
        </li>
      </ul>
    </nav>
    <div class="sidebar-footer">
      <div class="footer-stat">
        <span class="stat-value">{{ store.totalDefines }}</span>
        <span class="stat-label">total defines</span>
      </div>
    </div>
  </aside>
</template>

<script setup lang="ts">
import { useGrammarStore } from '@/stores/grammarStore'

const store = useGrammarStore()
</script>

<style scoped>
.sidebar {
  width: 260px;
  min-width: 260px;
  background: var(--bg-sidebar);
  border-right: 1px solid var(--border-color);
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.sidebar-header {
  padding: 16px;
  border-bottom: 1px solid var(--border-color);
}

.sidebar-title {
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--text-muted);
  margin: 0;
}

.sidebar-nav {
  flex: 1;
  overflow-y: auto;
  padding: 8px;
}

.grammar-list {
  list-style: none;
  margin: 0;
  padding: 0;
}

.grammar-item {
  padding: 10px 12px;
  border-radius: 6px;
  cursor: pointer;
  transition: background 0.15s;
  margin-bottom: 2px;
}

.grammar-item:hover {
  background: var(--bg-hover);
}

.grammar-item.active {
  background: var(--bg-active);
  border-left: 3px solid var(--color-primary);
  padding-left: 9px;
}

.grammar-name {
  font-size: 14px;
  font-weight: 500;
  color: var(--text-primary);
}

.grammar-meta {
  font-size: 11px;
  color: var(--text-muted);
  margin-top: 2px;
}

.sidebar-footer {
  padding: 12px 16px;
  border-top: 1px solid var(--border-color);
  display: flex;
  gap: 16px;
}

.footer-stat {
  display: flex;
  align-items: baseline;
  gap: 4px;
}

.stat-value {
  font-size: 16px;
  font-weight: 600;
  color: var(--color-primary);
}

.stat-label {
  font-size: 11px;
  color: var(--text-muted);
}
</style>
