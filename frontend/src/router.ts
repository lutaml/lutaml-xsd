import { createRouter, createWebHashHistory } from 'vue-router'

const router = createRouter({
  history: createWebHashHistory(),
  routes: [
    {
      path: '/',
      name: 'home',
      component: () => import('./views/HomeView.vue')
    },
    {
      path: '/schema/:id',
      name: 'schema',
      component: () => import('./views/SchemaView.vue'),
      props: true
    },
    {
      path: '/playground',
      name: 'playground',
      component: () => import('./views/PlaygroundView.vue')
    }
  ]
})

export default router
