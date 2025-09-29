import connectToMongoDB from "./config/configMongoDB.config.js";
import express from 'express'
import authRouter from "./routes/auth.router.js";
import workspaceRouter from "./routes/workspace.router.js";
import randomMiddleware from "./middlewares/random.middleware.js";
import handlebars from 'express-handlebars';
import WorkspaceRepository from "./repositories/workspace.repository.js";

connectToMongoDB()

const app = express()


app.use(express.json())

/* Permite que nuestro servidor pueda servir archivos configurando de donde se van a servir */
app.use(express.static('./public'))

//CONFIGURACIÓN DE HANDLEBARS
//El motor de plantilla de mi app es Handlebars
app.engine('handlebars', handlebars.engine({
    runtimeOptions: {
        allowProtoPropertiesByDefault: true,
        allowProtoMethodsByDefault: true,
    }
}));

//El motor de vistas es Handlebars
app.set('view engine', 'handlebars')

//Las vistas/plantillas vienen en esta dirección
app.set('views', './views')


//Todas las consultas que empiezen con /api/auth va a ser gestionadas por el authRouter
app.use('/api/auth', authRouter)
app.use('/api/workspace', workspaceRouter)



//Quiero que falle cuando sea mayor a 0.5
app.get(
    '/ping',
    /* Middleware */
    randomMiddleware(0.5),
    (request, response) => {
        console.log("llego un ping")
        response.send({ ok: true })
    }
)


//Quiero que falle cuando sea mayor a 0.1
app.get(
    '/ping-2',
    /* Middleware */
    randomMiddleware(0.1),
    (request, response) => {
        console.log("llego un ping")
        response.send({ ok: true })
    }
)

//Quiero que falle cuando sea mayor a 0.9
app.get(
    '/ping-3',
    /* Middleware */
    randomMiddleware(0.9),
    (request, response) => {
        console.log("llego un ping")
        response.send({ ok: true })
    }
)

app.get('/home', async (request, response) => {
    response.render('home', {
        users: ['Ian', 'Mati', 'Ana', 'Luis'],
        workspaces: [
            { name: 'Workspace 1', description: 'Primer espacio de trabajo' },
            { name: 'Workspace 2', description: 'Segundo espacio de trabajo' },
            { name: 'Workspace 3', description: 'Tercer espacio de trabajo' }
        ]
    });
});

const PORT = 8080

app.listen(
    PORT,
    () => {
        console.log(`Tu servidor se esta ejecutando correctamente en el puerto ${PORT}`)
    }
)

