export default function randomMiddleware(probabilidad) {
    return (req, res, next) => {
        if (Math.random() > probabilidad) {
            next();
        } else {
            res.status(500).send({ error: "Error aleatorio por middleware" });
        }
    };
}