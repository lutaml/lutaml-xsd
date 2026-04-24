<template>
  <div v-if="tree" class="model-tree">
    <div class="tree-header">
      <h2 class="tree-title">Model Tree</h2>
      <div class="tree-file">{{ grammar?.file_path }}</div>
    </div>
    <div class="tree-scroll">
      <ul class="tree-root">
        <TreeNode :node="tree" :depth="0" />
      </ul>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useGrammarStore } from '@/stores/grammarStore'
import TreeNode from './TreeNode.vue'

const store = useGrammarStore()
const grammar = computed(() => store.selectedGrammar)
const tree = computed(() => grammar.value?.model_tree)
</script>

<style scoped>
.model-tree {
  display: flex;
  flex-direction: column;
  height: 100%;
  overflow: hidden;
}

.tree-header {
  padding: 16px;
  border-bottom: 1px solid var(--border-color);
}

.tree-title {
  font-size: 13px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--text-muted);
  margin: 0 0 4px 0;
}

.tree-file {
  font-size: 12px;
  font-family: var(--font-mono);
  color: var(--text-muted);
}

.tree-scroll {
  flex: 1;
  overflow: auto;
  padding: 12px 16px;
}

.tree-root {
  margin: 0;
  padding: 0;
  list-style: none;
  font-size: 12px;
}
</style>
