# Clase 15 - Node.js

## Temas principales
- Modularización avanzada con Express
- Uso de routers y middlewares personalizados
- Integración de Handlebars para vistas dinámicas
- Renderizado de listas y objetos con `#each`
- Práctica: mostrar usuarios y espacios de trabajo

## Ejemplo de código
```js
app.get('/home', (req, res) => {
  res.render('home', {
    users: ['Ian', 'Mati', 'Ana', 'Luis'],
    workspaces: [
      { name: 'Workspace 1', description: 'Primer espacio de trabajo' },
      { name: 'Workspace 2', description: 'Segundo espacio de trabajo' },
      { name: 'Workspace 3', description: 'Tercer espacio de trabajo' }
    ]
  });
});
```

## Ejemplo de vista Handlebars
```handlebars
<h2>Usuarios:</h2>
<ul>
  {{#each users}}
    <li>{{this}}</li>
  {{/each}}
</ul>

<h2>Espacios de trabajo:</h2>
<ul>
  {{#each workspaces}}
    <li><strong>{{name}}</strong>: {{description}}</li>
  {{/each}}
</ul>
```

---

## Buenas prácticas
- Separar rutas, controladores y middlewares
- Documentar endpoints y estructura
- Usar motores de vistas para contenido dinámico
