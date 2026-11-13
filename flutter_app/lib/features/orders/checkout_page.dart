import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_states.dart';
import '../../core/widgets/design_components.dart';
import '../customer/customer_cart.dart';
import 'orders_api.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key, required this.client});
  final ApiClient client;
  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  late final OrdersApi _api = OrdersApi(widget.client);
  late final CustomerCart _cart = CustomerCart(_api);
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(), _phone = TextEditingController();
  final _address = TextEditingController(), _area = TextEditingController();
  final _pin = TextEditingController(), _house = TextEditingController();
  final _landmark = TextEditingController(),
      _instructions = TextEditingController();
  DateTime _date = DateTime.now();
  String _slot = 'MORNING';
  bool _placing = false;
  String? _checkoutIdempotencyKey;

  @override
  void initState() {
    super.initState();
    _checkoutIdempotencyKey = 'chk_${DateTime.now().millisecondsSinceEpoch}_${(1000 + (DateTime.now().microsecond % 9000))}';
    _cart.load().then((_) {
      if (mounted) setState(() {});
    }).catchError((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _cart.dispose();
    for (final c in [
      _name,
      _phone,
      _address,
      _area,
      _pin,
      _house,
      _landmark,
      _instructions
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;
  Future<void> _place() async {
    if (_placing || !_form.currentState!.validate() || _cart.lines.isEmpty) return;
    setState(() => _placing = true);
    try {
      final order = await _api.placeOrder(
        idempotencyKey: _checkoutIdempotencyKey,
        cart: _cart.snapshot,
        recipientName: _name.text.trim(),
        recipientPhone: _phone.text.trim(),
        addressLine: _address.text.trim(),
        houseNumber: _house.text.trim().isEmpty ? null : _house.text.trim(),
        area: _area.text.trim(),
        pincode: _pin.text.trim(),
        landmark: _landmark.text.trim().isEmpty ? null : _landmark.text.trim(),
        deliveryInstructions: _instructions.text.trim().isEmpty
            ? null
            : _instructions.text.trim(),
        deliveryDate: _date,
        deliverySlot: _slot,
      );
      if (!mounted) return;
      await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
                icon: const Icon(Icons.check_circle_rounded,
                    color: AppColors.green, size: 44),
                title: const Text('Order confirmed'),
                content: Text(
                    'Order ${order.orderNumber} is placed. Your total is ₹${order.totalAmount.toStringAsFixed(2)}. Pay in cash when the order arrives. Delivery OTP: ${order.deliveryOtp ?? 'refresh it from My Orders'}.'),
                actions: [
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Done'))
                ],
              ));
      if (mounted) Navigator.pop(context, order);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_api.describeError(error))));
      }
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  Widget _section(String title, IconData icon, List<Widget> children) => Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icon, color: AppColors.green, size: 20),
                const SizedBox(width: 9),
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800))
              ]),
              const SizedBox(height: 12),
              ...children,
            ])),
      );
  Widget _field(TextEditingController controller, String label,
          {String? Function(String?)? validator,
          TextInputType? keyboardType,
          String? hint}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: label, hintText: hint),
              validator: validator));
  Future<void> _pickDate() async {
    final today = DateTime.now();
    final value = await showDatePicker(
        context: context,
        initialDate: _date,
        firstDate: DateTime(today.year, today.month, today.day),
        lastDate: today.add(const Duration(days: 30)));
    if (value != null) setState(() => _date = value);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const FreshBasketAppBar(title: Text('Checkout')),
        body: _cart.loading
            ? const LoadingState(message: 'Preparing your basket...')
            : _cart.lines.isEmpty
                ? const EmptyState(
                    icon: Icons.shopping_basket_outlined,
                    title: 'Your basket is empty',
                    message: 'Add vegetables before you check out.')
                : Form(
                    key: _form,
                    child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 116),
                        children: [
                          Text('Almost there',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(
                              'Confirm your delivery details and place your order.',
                              style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 14),
                          _section(
                              'Delivery address', Icons.location_on_outlined, [
                            _field(_house, 'House / flat number',
                                hint: 'Optional'),
                            _field(_address, 'Street address',
                                validator: _required),
                            _field(_area, 'Area / city', validator: _required),
                            _field(_pin, '6 digit pincode',
                                keyboardType: TextInputType.number,
                                validator: (v) => v == null ||
                                        !RegExp(r'^[0-9]{6}$')
                                            .hasMatch(v.trim())
                                    ? 'Enter a 6 digit pincode'
                                    : null),
                            _field(_landmark, 'Landmark', hint: 'Optional'),
                          ]),
                          const SizedBox(height: 10),
                          _section(
                              'Contact details', Icons.person_outline_rounded, [
                            _field(_name, 'Recipient name',
                                validator: _required),
                            _field(_phone, 'Phone number',
                                keyboardType: TextInputType.phone,
                                validator: (v) => v == null ||
                                        !RegExp(r'^[0-9+() -]{7,20}$')
                                            .hasMatch(v.trim())
                                    ? 'Enter a valid phone number'
                                    : null),
                          ]),
                          const SizedBox(height: 10),
                          _section('Delivery time', Icons.schedule_rounded, [
                            ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                    Icons.calendar_today_outlined,
                                    color: AppColors.green),
                                title: const Text('Delivery date'),
                                subtitle: Text(
                                    '${_date.day}/${_date.month}/${_date.year}'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: _pickDate),
                            DropdownButtonFormField<String>(
                                initialValue: _slot,
                                decoration: const InputDecoration(
                                    labelText: 'Preferred time slot'),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'MORNING', child: Text('Morning')),
                                  DropdownMenuItem(
                                      value: 'AFTERNOON',
                                      child: Text('Afternoon')),
                                  DropdownMenuItem(
                                      value: 'EVENING', child: Text('Evening'))
                                ],
                                onChanged: (value) =>
                                    setState(() => _slot = value ?? 'MORNING')),
                            const SizedBox(height: 10),
                            TextFormField(
                                controller: _instructions,
                                minLines: 1,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                    labelText: 'Delivery instructions',
                                    hintText: 'Optional')),
                          ]),
                          const SizedBox(height: 10),
                          _section('Your vegetables',
                              Icons.shopping_basket_outlined, [
                            ..._cart.lines.map((line) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                child: Row(children: [
                                  Expanded(
                                      child: Text(
                                          '${line.name} · ${line.quantity} ${line.unit.toLowerCase()}')),
                                  PriceText(amount: line.lineTotal)
                                ]))),
                            const Divider(height: 22),
                            _summaryRow('Subtotal', _cart.subtotal),
                            const SizedBox(height: 8),
                            Row(children: [
                              Expanded(
                                  child: Text('Delivery fee',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall)),
                              Text('Confirmed with order',
                                  style: Theme.of(context).textTheme.bodySmall)
                            ]),
                          ]),
                          const SizedBox(height: 10),
                          Card(
                              color: AppColors.paleGreen,
                              child: const ListTile(
                                  leading: Icon(Icons.payments_outlined,
                                      color: AppColors.darkGreen),
                                  title: Text('Cash on delivery',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  subtitle: Text(
                                      'Pay your driver when the order arrives.'))),
                        ])),
        bottomNavigationBar: _cart.lines.isEmpty || _cart.loading
            ? null
            : SafeArea(
                child: Container(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                    decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(top: BorderSide(color: AppColors.line))),
                    child: Row(children: [
                      Expanded(
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('Subtotal',
                                style: Theme.of(context).textTheme.bodySmall),
                            PriceText(
                                amount: _cart.subtotal,
                                emphasized: true,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800))
                          ])),
                      const SizedBox(width: 12),
                      Expanded(
                          flex: 2,
                          child: SizedBox(
                              height: 50,
                              child: FilledButton(
                                  onPressed: _placing ? null : _place,
                                  child: _placing
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2))
                                      : const Text('Place COD order'))))
                    ]))),
      );
  Widget _summaryRow(String label, num amount) => Row(children: [
        Expanded(child: Text(label)),
        PriceText(amount: amount, emphasized: true)
      ]);
}
