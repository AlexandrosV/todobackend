from django.core.urlresolvers import reverse
from rest_framework import status
from rest_framework.test import APITestCase
from todo.models import TodoItem


# Create your tests here.
def createItem(client):
    url = reverse('todoitem-list')
    data = {'title': 'Perform unit testing'}
    return client.post(url, data, format='json')


# Test create TodoItem
class TestCreateTodoItem(APITestCase):
    """
    Ensure that we can create a new todo item
    """
    def setUp(self):
        self.response = createItem(self.client)

    def test_received_201_created_status_code(self):
        self.assertEqual(self.response.status_code, status.HTTP_201_CREATED)

    def test_received_location_header_hyperlink(self):
        self.assertRegexpMatches(self.response['Location'], '^http://.+/todos/[\d]+$')

    def test_item_was_created(self):
        self.assertEqual(TodoItem.objects.count(), 1)

    def test_item_has_correct_title(self):
        self.assertEqual(TodoItem.objects.get().title, 'Perform unit testing')


# Test update TodoItem using PUT verb
class TestUpdateTodoItem(APITestCase):
    """
    Ensure that we can update an existing todo item using PUT
    """
    def setUp(self):
        response = createItem(self.client)
        self.assertEqual(TodoItem.objects.get().completed, False)
        url = response['Location']
        data = {'title': 'Perform unit testing', 'completed': True}
        self.response = self.client.put(url, data, format='json')

    def test_received_200_created_status_code(self):
        self.assertEqual(self.response.status_code, status.HTTP_200_OK)

    def test_item_was_updated(self):
        self.assertEqual(TodoItem.objects.get().completed, True)


# Test update TodoItem using PATCH verb
class TestPatchTodoItem(APITestCase):
    """
    Ensure that we can update an existing todo item using PATCH
    """
    def setUp(self):
        response = createItem(self.client)
        self.assertEqual(TodoItem.objects.get().completed, False)
        url = response['Location']
        data = {'title': 'perform unit testing', 'completed': True}
        self.response = self.client.patch(url, data, format='json')

    def test_received_200_ok_status_code(self):
        self.assertEqual(self.response.status_code, status.HTTP_200_OK)

    def test_item_was_updated(self):
        self.assertEqual(TodoItem.objects.get().completed, True)


# Test delete TodoItem
class TestDeleteTodoItem(APITestCase):
    """
    Ensure that we can delete an existing todo item using DELETE
    """
    def setUp(self):
        response = createItem(self.client)
        self.assertEqual(TodoItem.objects.count(), 1)
        url = response['Location']
        self.response = self.client.delete(url)

    def test_received_204_no_content_status_code(self):
        self.assertEqual(self.response.status_code, status.HTTP_204_NO_CONTENT)

    def test_all_items_were_deleted(self):
        self.assertEqual(TodoItem.objects.count(), 0)


