<template>
  <div class="app-layout">
    <GrammarSidebar />
    <div class="main-content">
      <header class="app-header">
        <h1 class="header-title">{{ store.metadata?.title || 'RNG Grammar Documentation' }}</h1>
        <span class="header-badge">{{ store.grammars.length }} grammar{{ store.grammars.length !== 1 ? 's' : '' }}</span>
      </header>
      <div class="content-area">
        <ModelTree v-if="store.selectedGrammar" />
        <div v-else class="empty-state">
          <p>Select a grammar from the sidebar</p>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { onMounted } from 'vue'
import { useGrammarStore } from '@/stores/grammarStore'
import GrammarSidebar from '@/components/GrammarSidebar.vue'
import ModelTree from '@/components/ModelTree.vue'

const store = useGrammarStore()

onMounted(() => {
  store.loadFromWindow()
})
</script>

<style scoped>
.app-layout {
  display: flex;
  height: 100vh;
  overflow: hidden;
}

.main-content {
  flex: 1;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  min-width: 0;
}

.app-header {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 16px 24px;
  border-bottom: 1px solid var(--border-color);
  background: var(--bg-elevated);
}

.header-title {
  font-size: 18px;
  font-weight: 600;
  color: var(--text-primary);
  margin: 0;
}

.header-badge {
  font-size: 12px;
  color: var(--text-muted);
  background: var(--bg-badge);
  padding: 2px 8px;
  border-radius: 10px;
}

.content-area {
  flex: 1;
  overflow: hidden;
  background: var(--bg-primary);
}

.empty-state {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 100%;
  color: var(--text-muted);
  font-size: 14px;
}
</style>
