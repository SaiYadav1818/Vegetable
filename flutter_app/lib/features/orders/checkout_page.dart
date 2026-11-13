import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
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
  final _name = TextEditingController(),
      _phone = TextEditingController(),
      _address = TextEditingController();
  final _area = TextEditingController(),
      _pin = TextEditingController(),
      _house = TextEditingController();
  final _landmark = TextEditingController(),
      _instructions = TextEditingController();
  DateTime _date = DateTime.now();
  String _slot = 'MORNING';
  bool _placing = false;

  @override
  void initState() {
    super.initState();
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
    if (!_form.currentState!.validate() || _cart.lines.isEmpty) return;
    setState(() => _placing = true);
    try {
      final order = await _api.placeOrder(
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
                title: const Text('Order placed'),
                content: Text(
                    'Order ${order.orderNumber} is confirmed. Pay Rs. ${order.totalAmount.toStringAsFixed(2)} in cash on delivery. Your delivery OTP is ${order.deliveryOtp ?? 'available in My Orders'}.'),
                actions: [
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Done'))
                ],
              ));
      if (mounted) Navigator.pop(context, order);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_api.describeError(error))));
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: _cart.loading
            ? const Center(child: CircularProgressIndicator())
            : _cart.lines.isEmpty
                ? const Center(child: Text('Your basket is empty'))
                : Form(
                    key: _form,
                    child:
                        ListView(padding: const EdgeInsets.all(18), children: [
                      Text('Delivery details',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 14),
                      TextFormField(
                          controller: _name,
                          decoration: const InputDecoration(
                              labelText: 'Recipient name'),
                          validator: _required),
                      TextFormField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          decoration:
                              const InputDecoration(labelText: 'Phone number'),
                          validator: (v) => v == null ||
                                  !RegExp(r'^[0-9+() -]{7,20}$')
                                      .hasMatch(v.trim())
                              ? 'Enter a valid phone number'
                              : null),
                      TextFormField(
                          controller: _house,
                          decoration: const InputDecoration(
                              labelText: 'House / flat number (optional)')),
                      TextFormField(
                          controller: _address,
                          decoration: const InputDecoration(
                              labelText: 'Street address'),
                          validator: _required),
                      TextFormField(
                          controller: _area,
                          decoration:
                              const InputDecoration(labelText: 'Area / city'),
                          validator: _required),
                      TextFormField(
                          controller: _landmark,
                          decoration: const InputDecoration(
                              labelText: 'Landmark (optional)')),
                      TextFormField(
                          controller: _pin,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: '6 digit pincode'),
                          validator: (v) => v == null ||
                                  !RegExp(r'^[0-9]{6}$').hasMatch(v.trim())
                              ? 'Enter a 6 digit pincode'
                              : null),
                      TextFormField(
                          controller: _instructions,
                          decoration: const InputDecoration(
                              labelText: 'Delivery instructions (optional)')),
                      const SizedBox(height: 16),
                      ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Delivery date'),
                          subtitle:
                              Text('${_date.day}/${_date.month}/${_date.year}'),
                          trailing: const Icon(Icons.calendar_month),
                          onTap: () async {
                            final today = DateTime.now();
                            final date = await showDatePicker(
                                context: context,
                                initialDate: _date,
                                firstDate: DateTime(
                                    today.year, today.month, today.day),
                                lastDate: today.add(const Duration(days: 30)));
                            if (date != null) setState(() => _date = date);
                          }),
                      DropdownButtonFormField<String>(
                          initialValue: _slot,
                          decoration: const InputDecoration(
                              labelText: 'Delivery time slot'),
                          items: const [
                            DropdownMenuItem(
                                value: 'MORNING', child: Text('Morning')),
                            DropdownMenuItem(
                                value: 'AFTERNOON', child: Text('Afternoon')),
                            DropdownMenuItem(
                                value: 'EVENING', child: Text('Evening')),
                          ],
                          onChanged: (value) =>
                              setState(() => _slot = value ?? 'MORNING')),
                      const SizedBox(height: 14),
                      Card(
                          child: ListTile(
                              leading: const Icon(Icons.payments_outlined),
                              title: const Text('Cash on delivery'),
                              subtitle: Text(
                                  '${_cart.lines.length} items · Rs. ${_cart.subtotal.toStringAsFixed(2)} before delivery charge'))),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                          onPressed: _placing ? null : _place,
                          icon: _placing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.check),
                          label: Text(_placing
                              ? 'Placing order...'
                              : 'Place COD order')),
                    ])),
      );
}
