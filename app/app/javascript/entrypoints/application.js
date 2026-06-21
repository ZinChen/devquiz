import { createApp, h } from 'vue'
import { createInertiaApp, router } from '@inertiajs/vue3'
import axios from 'axios'
import '../app.css'

axios.defaults.headers.common['X-CSRF-Token'] = document.querySelector('meta[name="csrf-token"]')?.content

function camelize(s) {
  return s.replace(/_([a-z])/g, (_, c) => c.toUpperCase())
}

function camelizeKeys(val) {
  if (Array.isArray(val)) return val.map(camelizeKeys)
  if (val !== null && typeof val === 'object') {
    return Object.fromEntries(Object.entries(val).map(([k, v]) => [camelize(k), camelizeKeys(v)]))
  }
  return val
}

axios.interceptors.response.use(response => {
  response.data = camelizeKeys(response.data)
  return response
})

router.on('success', (event) => {
  event.detail.page.props = camelizeKeys(event.detail.page.props)
})

createInertiaApp({
  resolve: name => {
    const pages = import.meta.glob('../pages/**/*.vue', { eager: true })
    return pages[`../pages/${name}.vue`]
  },
  setup({ el, App, props, plugin }) {
    props.initialPage.props = camelizeKeys(props.initialPage.props)
    createApp({ render: () => h(App, props) })
      .use(plugin)
      .mount(el)
  },
  progress: {
    color: '#4F63F5',
  },
})
