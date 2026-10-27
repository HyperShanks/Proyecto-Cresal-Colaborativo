// frontend/test/features/gerencia/backorders_gerencia_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/gerencia/models/backorder_gerencia_models.dart';
import 'package:frontend/features/gerencia/presentation/screens/backorders_gerencia_view.dart';
import 'package:frontend/features/gerencia/presentation/widgets/kpi_card_widget.dart';
import 'package:frontend/features/gerencia/presentation/widgets/backorder_auditoria_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HU-5.4: Modelos de Backorders', () {
    test('BackorderItemModel deserializa correctamente todos los campos', () {
      final json = {
        'id_reserva': 'res-001',
        'folio': 'RES-5401',
        'fecha_creacion': 'Hoy 10:15',
        'fecha_creacion_iso': '2026-09-08T10:15:00Z',
        'id_cliente': 'cli-101',
        'cliente_nombre': 'Marcelo Gómez T.',
        'cliente_telefono': '+56987654321',
        'cliente_rut': '18.111.222-3',
        'id_vendedor': 'usr-201',
        'vendedor_nombre': 'Gastón Zamora',
        'id_sucursal': 1,
        'sucursal_nombre': 'Casa Matriz (Viña)',
        'id_categoria_requerida': 1,
        'categoria_nombre': 'Motor',
        'marca_requerida': 'Mitsubishi',
        'modelo_requerido': 'L200 Dakar',
        'anio_requerido': 2021,
        'cilindrada_requerida': '2.4',
        'combustible_requerido': 'Diesel',
        'transmision_requerida': 'Automática',
        'notas_preparacion': 'Revisar inyectores',
        'precio_acordado': 2100000,
        'monto_abonado': 500000,
        'saldo_pendiente': 1600000,
        'estado_reserva': 'Confirmada',
        'id_activo_asignado': 'act-901',
        'activo_asignado_sku': 'MOT-9001-A1',
        'id_orden': 'ord-777',
        'orden_folio': 'ORD-0436',
        'estado_orden': 'Pagada',
      };

      final item = BackorderItemModel.fromJson(json);

      expect(item.idReserva, 'res-001');
      expect(item.folio, 'RES-5401');
      expect(item.fechaCreacion, 'Hoy 10:15');
      expect(item.clienteNombre, 'Marcelo Gómez T.');
      expect(item.vendedorNombre, 'Gastón Zamora');
      expect(item.idSucursal, 1);
      expect(item.idCategoriaRequerida, 1);
      expect(item.marcaRequerida, 'Mitsubishi');
      expect(item.modeloRequerido, 'L200 Dakar');
      expect(item.anioRequerido, 2021);
      expect(item.precioAcordado, 2100000);
      expect(item.montoAbonado, 500000);
      expect(item.saldoPendiente, 1600000);
      expect(item.estadoReserva, 'Confirmada');
      expect(item.idActivoAsignado, 'act-901');
      expect(item.activoAsignadoSku, 'MOT-9001-A1');
      expect(item.idOrden, 'ord-777');
      expect(item.ordenFolio, 'ORD-0436');
      expect(item.estadoOrden, 'Pagada');
    });

    test('BackordersKpisModel deserializa correctamente métricas ejecutivas', () {
      final json = {
        'total_activos': 12,
        'capital_retenido': 4800000,
        'listos_para_liquidar': 3,
        'total_registrados': 28,
        'total_recaudado_senas': 9500000,
      };

      final kpis = BackordersKpisModel.fromJson(json);

      expect(kpis.totalActivos, 12);
      expect(kpis.capitalRetenido, 4800000);
      expect(kpis.listosParaLiquidar, 3);
      expect(kpis.totalRegistrados, 28);
      expect(kpis.totalRecaudadoSenas, 9500000);
    });

    test('PaginatedBackordersResponse deserializa items y totales', () {
      final json = {
        'total_count': 1,
        'total_recaudado_senas': 350000,
        'items': [
          {
            'id_reserva': 'res-002',
            'folio': 'RES-5402',
            'fecha_creacion': 'Ayer 15:30',
            'fecha_creacion_iso': '2026-09-07T15:30:00Z',
            'id_cliente': 'cli-102',
            'cliente_nombre': 'Flotas del Puerto S.A.',
            'id_vendedor': 'usr-202',
            'vendedor_nombre': 'Ignacio Vendedor',
            'id_sucursal': 2,
            'sucursal_nombre': 'Patio Desarme (Limache)',
            'id_categoria_requerida': 2,
            'categoria_nombre': 'Caja de Cambios',
            'marca_requerida': 'Toyota',
            'modelo_requerido': 'Hilux',
            'anio_requerido': 2019,
            'precio_acordado': 980000,
            'monto_abonado': 350000,
            'saldo_pendiente': 630000,
            'estado_reserva': 'Confirmada',
          }
        ],
      };

      final res = PaginatedBackordersResponse.fromJson(json);
      expect(res.totalCount, 1);
      expect(res.totalRecaudadoSenas, 350000);
      expect(res.items.length, 1);
      expect(res.items.first.folio, 'RES-5402');
      expect(res.items.first.idCategoriaRequerida, 2);
    });
  });

  group('HU-5.4: Componente BackordersGerenciaView', () {
    testWidgets('Renderiza 3 tarjetas KPI, buscador y filtros en estado inicial', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BackordersGerenciaView(
              idSucursalInicial: null,
            ),
          ),
        ),
      );

      // Esperar primer frame
      await tester.pump();

      // Verificamos presencia de las 3 tarjetas KPI
      expect(find.byType(KpiCardWidget), findsNWidgets(3));
      expect(find.text('TOTAL VENTAS EN VERDE ACTIVAS'), findsOneWidget);
      expect(find.text('CAPITAL RETENIDO EN ABONOS'), findsOneWidget);
      expect(find.text('LISTOS PARA LIQUIDAR'), findsOneWidget);

      // Verificamos presencia del input de búsqueda con su placeholder
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Buscar por Marca, Modelo, Cliente o Vendedor...'), findsOneWidget);

      // Verificamos presencia del selector de estado y botón Limpiar
      expect(find.text('Estado: Todos'), findsOneWidget);
      expect(find.text('Limpiar'), findsOneWidget);

      // En la carga inicial se muestra el indicador de carga
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('HU-Auditoría: BackorderAuditoriaDialog y Modelos Forenses', () {
    test('BackorderAuditoriaModel deserializa ficha completa, pagos y timeline', () {
      final json = {
        'id_reserva': 'res-101',
        'folio': 'RES-9901',
        'fecha_creacion': '27/10/26 10:00 hrs',
        'fecha_creacion_iso': '2026-10-27T10:00:00Z',
        'estado_reserva': 'Confirmada',
        'id_orden': 'ord-202',
        'orden_folio': 'ORD-0436',
        'estado_orden': 'Pagada',
        'id_cliente': 'cli-303',
        'cliente_nombre': 'Transportes Aconcagua SpA',
        'cliente_rut': '76.123.456-K',
        'cliente_telefono': '+56912345678',
        'cliente_correo': 'contacto@aconcagua.cl',
        'id_vendedor': 'usr-404',
        'vendedor_nombre': 'Pedro Ventas',
        'id_sucursal': 1,
        'sucursal_nombre': 'Casa Matriz (Viña)',
        'id_categoria_requerida': 1,
        'categoria_nombre': 'Motor',
        'marca_requerida': 'Toyota',
        'modelo_requerido': 'Hilux',
        'anio_requerido': 2020,
        'cilindrada_requerida': '2.8',
        'combustible_requerido': 'Diesel',
        'transmision_requerida': 'Mecánica',
        'notas_preparacion': 'Requiere prueba de compresión',
        'precio_acordado': 1800000,
        'descuento': 50000,
        'monto_abonado': 600000,
        'saldo_pendiente': 1150000,
        'id_activo_asignado': 'act-505',
        'activo_asignado_sku': 'MOT-8001-B2',
        'vehiculo_donante_ingreso': 'ING-440',
        'vehiculo_donante_patente': 'LP-9988',
        'vehiculo_donante_descripcion': 'Toyota Hilux 2020',
        'desglose_pagos': [
          {
            'id_transaccion': 'tx-1',
            'metodo_pago': 'Transferencia',
            'monto': 600000,
            'fecha_pago': '27/10/26 10:15 hrs',
            'cajero_nombre': 'Cajera Central',
          }
        ],
        'movimientos': [
          {
            'hora': '27/10/26 10:00 hrs',
            'evento': 'Reserva de Venta en Verde emitida en Mesón por Pedro Ventas',
          },
          {
            'hora': '27/10/26 10:15 hrs',
            'evento': 'Abono de seña registrado en ventanilla: Transferencia (\$600.000) por Cajera Central',
          },
          {
            'hora': '27/10/26 11:30 hrs',
            'evento': 'Pieza física asignada (SKU: MOT-8001-B2) desde vehículo donante N° Ingreso ING-440 [LP-9988]',
          },
        ],
      };

      final auditoria = BackorderAuditoriaModel.fromJson(json);

      expect(auditoria.idReserva, 'res-101');
      expect(auditoria.folio, 'RES-9901');
      expect(auditoria.ordenFolio, 'ORD-0436');
      expect(auditoria.clienteNombre, 'Transportes Aconcagua SpA');
      expect(auditoria.clienteRut, '76.123.456-K');
      expect(auditoria.clienteTelefono, '+56912345678');
      expect(auditoria.clienteCorreo, 'contacto@aconcagua.cl');
      expect(auditoria.precioAcordado, 1800000);
      expect(auditoria.descuento, 50000);
      expect(auditoria.montoAbonado, 600000);
      expect(auditoria.saldoPendiente, 1150000);
      expect(auditoria.activoAsignadoSku, 'MOT-8001-B2');
      expect(auditoria.vehiculoDonanteIngreso, 'ING-440');
      expect(auditoria.desglosePagos.length, 1);
      expect(auditoria.desglosePagos.first.metodoPago, 'Transferencia');
      expect(auditoria.movimientos.length, 3);
      expect(auditoria.movimientos.first.hora, '27/10/26 10:00 hrs');
    });

    testWidgets('BackorderAuditoriaDialog renderiza cabecera, cliente, técnica, finanzas y timeline de solo lectura', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const itemMock = BackorderItemModel(
        idReserva: 'res-test-1',
        folio: 'RES-8801',
        fechaCreacion: 'Hoy 11:00',
        fechaCreacionIso: '2026-10-27T11:00:00Z',
        idCliente: 'cli-1',
        clienteNombre: 'Felipe Valenzuela',
        clienteTelefono: '+56998877665',
        clienteRut: '17.888.999-0',
        idVendedor: 'usr-1',
        vendedorNombre: 'Marcos Vendedor',
        idSucursal: 1,
        sucursalNombre: 'Viña del Mar',
        idCategoriaRequerida: 1,
        categoriaNombre: 'Motor',
        marcaRequerida: 'Nissan',
        modeloRequerido: 'Navara',
        anioRequerido: 2019,
        cilindradaRequerida: '2.5',
        combustibleRequerido: 'Diesel',
        transmisionRequerida: 'Mecánica',
        notasPreparacion: 'Sin turbo',
        precioAcordado: 1500000,
        montoAbonado: 500000,
        saldoPendiente: 1000000,
        estadoReserva: 'Confirmada',
        idActivoAsignado: 'act-1',
        activoAsignadoSku: 'MOT-7700-N1',
        idOrden: 'ord-1',
        ordenFolio: 'ORD-0120',
        estadoOrden: 'Reservada',
      );

      final auditoriaMock = BackorderAuditoriaModel(
        idReserva: 'res-test-1',
        folio: 'RES-8801',
        fechaCreacion: 'Hoy 11:00',
        fechaCreacionIso: '2026-10-27T11:00:00Z',
        estadoReserva: 'Confirmada',
        idOrden: 'ord-1',
        ordenFolio: 'ORD-0120',
        estadoOrden: 'Reservada',
        idCliente: 'cli-1',
        clienteNombre: 'Felipe Valenzuela',
        clienteRut: '17.888.999-0',
        clienteTelefono: '+56998877665',
        clienteCorreo: 'felipe.valenzuela@test.cl',
        idVendedor: 'usr-1',
        vendedorNombre: 'Marcos Vendedor',
        idSucursal: 1,
        sucursalNombre: 'Viña del Mar',
        idCategoriaRequerida: 1,
        categoriaNombre: 'Motor',
        marcaRequerida: 'Nissan',
        modeloRequerido: 'Navara',
        anioRequerido: 2019,
        cilindradaRequerida: '2.5',
        combustibleRequerido: 'Diesel',
        transmisionRequerida: 'Mecánica',
        notasPreparacion: 'Sin turbo',
        precioAcordado: 1500000,
        montoAbonado: 500000,
        saldoPendiente: 1000000,
        idActivoAsignado: 'act-1',
        activoAsignadoSku: 'MOT-7700-N1',
        movimientos: const [
          BackorderMovimientoModel(
            hora: '27/10/26 11:00 hrs',
            evento: 'Reserva de Venta en Verde emitida en Mesón por Marcos Vendedor (Viña del Mar)',
          ),
          BackorderMovimientoModel(
            hora: '27/10/26 11:15 hrs',
            evento: 'Abono inicial de seña registrado en caja por \$500.000',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => BackorderAuditoriaDialog.show(
                  context,
                  itemMock,
                  auditoriaInicial: auditoriaMock,
                ),
                child: const Text('Abrir Auditoría'),
              ),
            ),
          ),
        ),
      );

      // Abrir modal
      await tester.tap(find.text('Abrir Auditoría'));
      await tester.pumpAndSettle();

      // 1. Cabecera y Resumen
      expect(find.text('AUDITORÍA DE VENTA EN VERDE'), findsOneWidget);
      expect(find.text('RES-8801'), findsOneWidget);
      expect(find.text('ORD-0120'), findsOneWidget);
      expect(find.text('Confirmada'), findsWidgets);

      // 2. Ficha de Cliente
      expect(find.text('FICHA DEL CLIENTE'), findsOneWidget);
      expect(find.text('Felipe Valenzuela'), findsOneWidget);
      expect(find.text('RUT: 17.888.999-0'), findsOneWidget);
      expect(find.text('+56998877665'), findsOneWidget);

      // 3. Ficha Técnica
      expect(find.text('ESPECIFICACIÓN TÉCNICA DEL REPUESTO'), findsOneWidget);
      expect(find.text('Nissan Navara (2019)'), findsOneWidget);
      expect(find.textContaining('MOT-7700-N1'), findsOneWidget);

      // 4. Desglose Financiero
      expect(find.text('DESGLOSE FINANCIERO DE LA OPERACIÓN'), findsOneWidget);
      expect(find.text('SALDO PENDIENTE:'), findsOneWidget);

      // 5. Línea de Tiempo
      expect(find.text('LÍNEA DE TIEMPO / TRAZABILIDAD CRONOLÓGICA'), findsOneWidget);

      // 6. Solo Lectura: Único botón interactivo es "Cerrar"
      expect(find.text('Cerrar'), findsOneWidget);
      expect(find.text('Cobrar'), findsNothing);
      expect(find.text('Editar'), findsNothing);
      expect(find.text('Reasignar'), findsNothing);

      // Cerrar diálogo
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
      expect(find.text('AUDITORÍA DE VENTA EN VERDE'), findsNothing);
    });
  });
}

