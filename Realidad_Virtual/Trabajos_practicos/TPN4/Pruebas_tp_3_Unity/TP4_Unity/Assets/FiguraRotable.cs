using UnityEngine;
using UnityEngine.InputSystem; // Necesario para Unity 6

// Clase POO encargada de leer el teclado y calcular el giro
public class ControladorEntrada
{
    private float velocidad;

    public ControladorEntrada(float vel)
    {
        velocidad = vel;
    }

    public Vector2 ObtenerRotacion(float deltaTime)
    {
        float ejeHorizontal = 0f;
        float ejeVertical = 0f;

        var teclado = Keyboard.current;
        if (teclado != null)
        {
            if (teclado.leftArrowKey.isPressed)  ejeHorizontal = 1f;
            if (teclado.rightArrowKey.isPressed) ejeHorizontal = -1f;
            if (teclado.upArrowKey.isPressed)    ejeVertical = 1f;
            if (teclado.downArrowKey.isPressed)  ejeVertical = -1f;
        }

        return new Vector2(ejeVertical, ejeHorizontal) * velocidad * deltaTime;
    }
}

// Componente principal que se adjunta al Cubo
public class FiguraRotable : MonoBehaviour
{
    public float velocidadRotacion = 100f;
    private ControladorEntrada controlador;

    void Start()
    {
        controlador = new ControladorEntrada(velocidadRotacion);
    }

    void Update()
    {
        Vector2 giro = controlador.ObtenerRotacion(Time.deltaTime);
        transform.Rotate(giro.x, giro.y, 0f, Space.World);
    }
}