%% PI7_ele_captura_serie_script.m
% -------------------------------------------------------------------------
% Qué hace : captura un bloque CSV emitido por un test del banco ESP32
%            (proyecto PlatformIO PI7_banco_pruebas), lo guarda como
%            datos_banco/PI7_ele_<nombre>_<fecha>_data.csv (junto a este script) y lo grafica.
%            Protocolo del firmware:
%                #CSV_INI <nombre>
%                col1,col2,...        <- encabezado, con unidad en el sufijo
%                v1,v2,...
%                #CSV_FIN
%            Las líneas que no son datos (eventos, resúmenes) se muestran en
%            la ventana de comandos y no se guardan.
% Recibe   : puerto, baudios y comandos (sección Configuración).
% Devuelve : tabla 'datos' en el workspace, archivo CSV y figura.
% Depende  : MATLAB R2019b o posterior (serialport). Ningún toolbox.
% Ojo      : cerrá el monitor serie de PlatformIO antes de correrlo.
%            Abrir el puerto reinicia el ESP32: el script espera el menú,
%            entra al test y recién después manda el comando de medición.
% Autor    : Grupo 7 (PI7) + Claude. 2026-11-03.
% -------------------------------------------------------------------------
clc, clear, close all

%% Configuración
puerto     = "COM5";       % Administrador de dispositivos → Puertos (COM y LPT)
baudios    = 115200;       % = BAUDIOS_SERIE de pi7_config.h
comandos   = ["t06", "lineal 1"];   % [test, comando que emite CSV]; ej.: ["t06", "seguir 2 30 20"]
timeout_s  = 300;          % [s] tiempo máximo esperando el #CSV_FIN
carpeta    = fullfile(fileparts(mfilename("fullpath")), "datos_banco");

%% Conexión
s = serialport(puerto, baudios, "Timeout", 5);
configureTerminator(s, "LF");
limpieza = onCleanup(@() delete(s));
flush(s);

% Cada comando salvo el último abre un test: hay que esperar su "#LISTO"
esperarListo(s, 8);                          % menú después del reinicio
for k = 1:numel(comandos)
    fprintf("> %s\n", comandos(k));
    writeline(s, comandos(k));
    if k < numel(comandos), esperarListo(s, 15); end
end

%% Lectura del bloque CSV
nombre = "";
encabezado = strings(0);
filas = {};
estado = 0;                      % 0: esperando #CSV_INI · 1: encabezado · 2: datos
t0 = tic;
while toc(t0) < timeout_s
    if s.NumBytesAvailable == 0
        pause(0.01);
        continue
    end
    linea = strtrim(readline(s));
    switch estado
        case 0
            disp(linea);
            if startsWith(linea, "#CSV_INI")
                nombre = strtrim(extractAfter(linea, "#CSV_INI"));
                estado = 1;
            end
        case 1
            encabezado = strtrim(split(linea, ","))';
            estado = 2;
        case 2
            if startsWith(linea, "#CSV_FIN"), break, end
            v = str2double(split(linea, ","))';
            if numel(v) == numel(encabezado) && all(~isnan(v))
                filas{end+1, 1} = v; %#ok<SAGROW>
            else
                disp(linea);     % evento intercalado
            end
    end
end
if estado < 2 || isempty(filas)
    error("No llegó ningún bloque CSV. ¿El comando emite un bloque CSV (lineal, seguir)?");
end

% Resumen que el firmware imprime después del bloque
t0 = tic;
while toc(t0) < 1.5
    if s.NumBytesAvailable > 0
        disp(strtrim(readline(s)));
        t0 = tic;
    else
        pause(0.05);
    end
end

%% Guardado
datos = array2table(vertcat(filas{:}), "VariableNames", cellstr(encabezado));
if ~isfolder(carpeta), mkdir(carpeta); end
archivo = fullfile(carpeta, sprintf("PI7_ele_%s_%s_data.csv", ...
    strrep(nombre, "_", "-"), string(datetime("now", "Format", "yyyyMMdd-HHmmss"))));
writetable(datos, archivo);
fprintf("Guardado: %s (%d filas)\n", archivo, height(datos));

%% Gráfico: cada columna contra la primera
nCol = width(datos);
figure("Name", nombre, "Color", "w");
tiledlayout(nCol - 1, 1, "TileSpacing", "compact");
x = datos{:, 1};
for k = 2:nCol
    nexttile;
    plot(x, datos{:, k}, ".-");
    grid on;
    ylabel(strrep(datos.Properties.VariableNames{k}, "_", "\_"));
    if k == 2, title(strrep(nombre, "_", "\_")); end
end
xlabel(strrep(datos.Properties.VariableNames{1}, "_", "\_"));

%% Función local
function esperarListo(s, timeout_s)
t0 = tic;
while toc(t0) < timeout_s
    if s.NumBytesAvailable > 0
        linea = strtrim(readline(s));
        disp(linea);
        if startsWith(linea, "#LISTO"), return, end
    else
        pause(0.05);
    end
end
warning("No llegó #LISTO en %d s: se sigue igual.", timeout_s);
end
