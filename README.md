# Juego de Snake en Hardware (HDMI) con Tang Nano 9K

Este proyecto documenta e implementa un juego clásico de **Snake** diseñado completamente en hardware (Verilog) sobre una FPGA **Tang Nano 9K** utilizando **Gowin EDA**. El sistema genera una salida de video HDMI nativa a 640x480 a 60Hz, recibe comandos de teclado desde el PC vía USB-UART y ejecuta toda la lógica de movimiento, colisiones, puntaje y renderizado en tiempo real sin microprocesador.

> **Nota sobre la documentación en PDF:** Este repositorio incluye un archivo PDF con la documentación/presentación detallada del proyecto. Debido a limitaciones del visor web de GitHub, el archivo puede no visualizarse directamente en línea; para consultarlo correctamente, haz clic sobre el archivo y selecciona la opción **Download** (Descargar).

---

## Arquitectura y Flujo de Datos

El diseño sigue una arquitectura modular en paralelo controlada por un módulo maestro (`top_module.v`), separando la captura de entradas, la lógica del juego y el renderizado de video:

### 1. Gestión de Relojes e Interfaz HDMI
* **Top Module (`top_module.v`):** Contenedor principal que instancia los módulos internos e interconecta los buses de datos y señales de control hacia los pines físicos de la FPGA (definidos en el archivo `.cst`).
* **Relojes (`Gowin_rPLL` y `CLKDIV`):** A partir del oscilador físico de **27 MHz** (Pin 52):
  1. Un **rPLL** multiplica la frecuencia para generar el reloj serial de alta velocidad (**125 MHz**).
  2. Un divisor de hardware (**CLKDIV**, `DIV_MODE = "5"`) divide esos 125 MHz entre 5 para obtener el reloj de píxel (**25 MHz**) requerido por el estándar VGA 640x480@60Hz.
* **Transmisor DVI (`DVI_TX_Top`):** IP Core nativo de Gowin configurado en modo **ELVDS** (Emulated LVDS) que codifica las señales RGB de 24 bits y sincronización hacia los canales diferenciales TMDS del puerto HDMI.

### 2. Controlador de Entradas (UART)
* **Receptor Serial (`uart_rx.v`):** Implementa recepción asíncrona a **115200 baudios** conectada al pin RX del puente USB-Serial de la placa (Pin 18). Recibe los caracteres ASCII `w`, `a`, `s`, `d` enviados desde una terminal serial en el PC (ej. PuTTY) y genera un bus de 8 bits (`rx_data`) junto con una bandera de validación (`rx_valid`).
* **Reinicio físico:** El botón `rst_n` de la placa restablece instantáneamente las coordenadas, el tamaño, el puntaje y las banderas de estado del juego.

### 3. Lógica del Juego y Puntaje (`snake_logic.v`)
Máquina de estados finitos que controla las mecánicas sobre una cuadrícula de **10x10** (100 casillas totales):
* **Cuerpo escalable (Bus aplanado de 500 bits):** Almacena hasta 100 segmentos en arreglos de registros (`body_x`, `body_y`) que se desplazan en cascada en cada `move_tick`. Para respetar las reglas de puertos en Verilog, un bloque `generate` empaqueta las 100 coordenadas de 5 bits en dos vectores aplanados (`body_x_flat` y `body_y_flat` de `[499:0]`).
* **Protección de dirección:** Utiliza un registro de dirección real (`actual_dir`) sincronizado con el movimiento físico de la serpiente, evitando giros instantáneos de 180° (auto-colisión accidental) al presionar teclas muy rápido.
* **Generación pseudo-aleatoria desacoplada:** Un contador continuo a 25 MHz (rango `0` a `9`) sirve como semilla para la manzana amarilla. Para evitar que ambas manzanas aparezcan en la misma casilla, la manzana roja utiliza la coordenada inversa (`9 - rand_x`, `9 - rand_y`).
* **Sistema de Puntaje en BCD (16 bits):**
  * **Manzana amarilla (Buena):** Suma **10 puntos** y hace crecer el cuerpo en 1 segmento.
  * **Manzana roja (Veneno):** Resta **5 puntos** (con límite mínimo de `0000`) y reduce el cuerpo en 1 segmento. Si la serpiente solo tiene la cabeza (`snake_length == 0`) y come veneno, pierde la partida.
  * **Implementación BCD:** El puntaje (`score[15:0]`) se maneja directamente en formato **Binary-Coded Decimal** (4 dígitos de 4 bits: Miles, Centenas, Decenas y Unidades, rango `0000` a `9999`) mediante lógica de acarreo y préstamo. Esto elimina la necesidad de sintetizar divisiones (`/ 10`) o módulos (`% 10`) en el controlador de video, ahorrando LUTs.
* **Condiciones de Fin de Juego:** Activa `game_win` al llenar el tablero (100 casillas) o `game_over` al chocar contra su propio cuerpo o morir por veneno. Al activarse cualquiera, la lógica congela el movimiento.

### 4. Renderizado Visual (`vga_controller.v`)
Genera los pulsos de sincronización (`hs`, `vs`, `de`) y evalúa cada píxel en tiempo real bajo una jerarquía estricta de capas:
1. **Pantallas de Fin de Juego:** Superpone en el centro el cartel geométrico **"YOU LOSE"** (letras amarillas sobre fondo rojo) o **"YOU WIN"** (letras azules sobre fondo dorado).
2. **Marcador Digital (7 Segmentos Virtual):** Ubicado en la esquina superior derecha sobre un recuadro negro. Lee directamente los cuatro bloques de 4 bits del bus `score` y los decodifica mediante una tabla de 7 segmentos para dibujar los 4 dígitos en blanco.
3. **Elementos del Juego y Tablero:** Dibuja la cabeza (azul claro), los segmentos activos del cuerpo evaluados en paralelo (azul oscuro), la manzana amarilla, la manzana roja y el fondo cuadriculado de 10x10 (bloques de 64x48 píxeles en dos tonos de verde).

---

## Resumen de Buses Principales

| Conexión | Bus / Señal | Ancho | Descripción |
| :--- | :--- | :--- | :--- |
| `uart_rx` → `snake_logic` | `rx_data` / `rx_valid` | 8 bits / 1 bit | Carácter ASCII de control (`w, a, s, d`) y pulso de dato válido. |
| `snake_logic` → `vga_controller` | `head_x/y`, `apple_*` | 5 bits c/u | Coordenadas en la cuadrícula de 10x10 (`0` a `9`). |
| `snake_logic` → `vga_controller` | `snake_length` | 7 bits | Cantidad de segmentos activos (hasta 100). |
| `snake_logic` → `vga_controller` | `body_x_flat`, `body_y_flat` | 500 bits c/u | Arreglo aplanado de los 100 segmentos del cuerpo ($100 \times 5$). |
| `snake_logic` → `vga_controller` | `score` | 16 bits | Puntaje en formato BCD de 4 dígitos (`0000` a `9999`). |
| `snake_logic` → `vga_controller` | `game_over`, `game_win` | 1 bit c/u | Banderas de congelamiento y activación de pantallas finales. |
| `vga_controller` → `DVI_TX_Top` | `r`, `g`, `b` | 8 bits c/u | Canales de color RGB de 24 bits totales. |

---

## Simulación y Ejecución en FPGA (Gowin EDA)

El repositorio incluye los archivos fuente de síntesis, restricciones físicas y los bancos de pruebas (*testbenches*) para verificar cada módulo de forma independiente:

* **Verificación (`test_benchs`):** Contiene los *testbenches* de cada módulo para simular y validar el comportamiento lógico (UART, lógica del juego, contador BCD y señales VGA) antes de sintetizar en hardware.
* **Implementación en hardware (`src/`):** Para compilar y ejecutar el juego en una FPGA **Tang Nano 9K** usando **Gowin EDA**, se deben agregar al proyecto y sintetizar **en conjunto** todos los archivos Verilog ubicados en la carpeta `src/` (módulos principales e IP Cores) junto con el archivo de restricciones físicas (`.cst`). Una vez generado el *bitstream*, basta con programarlo en la placa, conectar el cable HDMI al monitor y abrir una terminal serial a 115200 baudios para jugar con `w`, `a`, `s`, `d`.
